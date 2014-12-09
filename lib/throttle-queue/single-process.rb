require 'thread'
# ThrottleQueue is a thread-safe rate-limited work queue. It allows both
# background and foreground operations.
#
# Example:
#   q = ThrottleQueue 3
#   files.each {|file|
#     q.background(file) {|id|
#       fetch file
#     }
#   }
class ThrottleQueue
	# Creates a new ThrottleQueue with the given rate limit (per second).
	def initialize(limit)
		raise "refusing to do zero work per second" if limit <= 0
		@limit = limit

		@queue = PriorityQueue.new

		@mutex = Mutex.new
		@pausing = ConditionVariable.new
		@idle = ConditionVariable.new
		@in_flight = nil
		@processing_thread = nil
		@items = {}

		@throttling = nil
		@state = :idle
		@t0 = Time.now
	end
	# Signals the queue to stop processing and shutdown.
	#
	# Items still in the queue are dropped. Any item
	# currently in flight will finish.
	def shutdown
		@queue.shutdown
		@pausing.signal
	end
	# Returns true if there is nothing queued and no
	# threads are running
	def idle?
		@state == :idle
	end
	# Blocks the calling thread while the queue processes work.
	#
	# Returns after the timeout has expired, or after the
	# queue returns to the idle state.
	def wait(timeout = nil)
		@mutex.synchronize {
			@idle.wait(@mutex, timeout) unless idle?
		}
	end
	# Adds work to the queue to run in the background, and
	# returns immediately.
	#
	# If the block takes an argument, it will be passed the
	# same id used to queue the work.
	def background(id, &block)
		@mutex.synchronize {
			unless @items.has_key? id
				@items[id] = block
				@queue.background id
				run
			end
		}
	end
	# Adds work to the queue ahead of all background work, and
	# blocks until the given block has been called.
	#
	# Will preempt an id of the same value in the
	# background queue, and wait on an id of the same value already
	# in the foreground queue.
	#
	# If the block takes an argument, it will be passed the
	# same id used to queue the work.
	def foreground(id, &block)
		t = nil
		@mutex.synchronize {
			if id == @in_flight
				t = @processing_thread unless @processing_thread == Thread.current
			else
				t = @items[id]
				unless t.is_a? FG
					t = @items[id] = FG.new block, self
					@queue.foreground id
					run
				end
			end
		}
		t.join if t
	end

	private
	def run
		return unless @state == :idle
		@state = :running
		@throttling = Thread.new {
			loop {
				break if @queue.shutdown? or @queue.empty?

				elapsed = Time.now - @t0
				wait_time = 1.0 / @limit + 0.01
				if @processing_thread and elapsed < wait_time
					@mutex.synchronize {
						@pausing.wait @mutex, wait_time - elapsed
					}
				end

				if id = @queue.pop
					@mutex.synchronize {
						@in_flight = id
						@processing_thread = Thread.new {
							block = @items[@in_flight]
							if block.arity == 0
								block.call
							else
								block.call @in_flight
							end
						}
					}
					@processing_thread.join if @processing_thread

					@mutex.synchronize {
						@items.delete @in_flight
						@in_flight = nil
					}
				end

				@t0 = Time.now
			}

			@mutex.synchronize {
				@state = :idle
				if @queue.shutdown? or @queue.empty?
					@idle.broadcast
				else
					# Restart to prevent a join deadlock
					send :run
				end
			}
		}
	end
	class FG #:nodoc: all
		def initialize(block, h)
			@block = block
			@thread = Thread.new {
				Thread.stop unless @args
				@block.call *@args
			}
			@h = h
		end
		def arity
			@block.arity
		end
		def call(*args)
			@args = args
			@thread.run
		end
		def join
			@thread.join
		end
	end
	class PriorityQueue #:nodoc: all
		def initialize
			@mutex = Mutex.new
			@fg = []
			@bg = []
			@received = ConditionVariable.new
			@shutdown = false
		end

		def shutdown
			@shutdown = true
			@received.signal
		end

		def shutdown?
			@shutdown
		end

		def empty?
			@mutex.synchronize {
				@fg.empty? and @bg.empty?
			}
		end

		def background(id)
			@mutex.synchronize {
				unless @shutdown || @bg.include?(id)
					@bg << id
					@received.signal
				end
			}
		end

		def foreground(id)
			@mutex.synchronize {
				unless @shutdown || @fg.include?(id)
					@fg << id
					if @bg.include?(id)
						@bg.delete id
					else
						@received.signal
					end
				end
			}
		end

		def pop
			@mutex.synchronize {
				if @fg.empty? and @bg.empty?
					@received.wait(@mutex) unless @shutdown
				end

				if @shutdown
				elsif ! @fg.empty?
					@fg.shift
				else
					@bg.shift
				end
			}
		end
	end
end
