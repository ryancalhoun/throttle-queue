require 'thread'

class ThrottleQueue
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

	def shutdown
		@queue.shutdown
		@pausing.signal
	end

	def idle?
		@state == :idle
	end

	def wait(timeout = nil)
		@mutex.synchronize {
			t0 = Time.now
			until idle?
				elapsed = Time.now - t0
				if timeout
					timeout -= elapsed
					break if timeout < 0
				end
				@idle.wait(@mutex, timeout)

				run unless @queue.shutdown? or @queue.empty?
			end
		}
	end

	def background(id, &block)
		@mutex.synchronize {
			if id != @in_flight
				@items[id] = block
				@queue.background id
				run
			end
		}
	end

	def foreground(id, &block)
		t = nil
		@mutex.synchronize {
			if id == @in_flight
				t = @processing_thread unless @processing_thread == Thread.current
			else
				b = @items[id]
				b.kill if b.is_a? FG

				t = @items[id] = FG.new block, self

				@queue.foreground id
				run
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
				end

				@t0 = Time.now
			}

			@mutex.synchronize {
				@state = :idle
				@idle.signal
			}
		}
	end
	class FG
		def initialize(block, h)
			@block = block
			@thread = Thread.new {
				Thread.stop
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
		def kill
			@thread.kill
		end
		def join
			@thread.join
		end
	end
	class PriorityQueue
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
