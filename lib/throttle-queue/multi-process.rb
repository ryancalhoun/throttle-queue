require 'drb'
require 'fileutils'
require 'tmpdir'
require_relative 'single-process.rb'

class ThrottleQueue
	# ThrottleQueue::MultiProcess is a wrapper around ThrottleQueue
	# that shares the queue between multiple processes.
	#
	# Example:
	#   q = ThrottleQueue::MultiProcess 3
	#   files.each {|file|
	#     q.background(file) {|id|
	#       fetch file
	#     }
	#   }
	class MultiProcess
		# Creates a new ThrottleQueue::MultiProcess with the given rate limit (per second).
		#
		# If this is the first instace of the shared queue, it becomes the master queue and
		# starts a DRbServer instace. If a DRbServer is already running, it connects to the
		# queue as a remote DRbObject.
		def initialize(limit, opt = {})
			opt[:name] ||= 'ThrottleQueue'
			opt[:host] ||= Socket.gethostbyname[0] rescue 'localhost'

			tmp = "#{Dir.tmpdir}/#{opt[:name]}.sock"
			FileUtils.touch tmp
			File.open(tmp, 'r+') {|f|
				f.flock File::LOCK_EX
				begin
					port = f.read.to_i
					uri = "druby://#{opt[:host]}:#{port}"
					if port == 0
						@queue = ThrottleQueue.new(limit)
						@drb = DRb.start_service uri, @queue
						f.seek 0, IO::SEEK_SET
						f.truncate 0
						f.write @drb.uri[/\d+$/]
						f.flock File::LOCK_UN
					else
						@queue = DRbObject.new_with_uri(uri)
						@queue.idle?
						@drb = DRb.start_service
						f.flock File::LOCK_UN
					end
				rescue DRb::DRbConnError
					f.seek 0, IO::SEEK_SET
					f.truncate 0
					retry
				end
			}

		end
		# Signals the queue to stop processing and shutdown.
		#
		# The DRbServer is shutdown in either the master process or any
		# client process.
		def shutdown
			@queue.shutdown
			@drb.stop_service if @drb
		end
		# Returns true if there is nothing queued and no
		# threads are running
		def idle?
			@queue.idle?
		end
		# Blocks the calling thread while the queue processes work.
		#
		# Returns after the timeout has expired, or after the
		# queue returns to the idle state.
		def wait(timeout = nil)
			begin
				@queue.wait(timeout)
			rescue DRb::DRbConnError
			end
		end
		# Adds work to the queue to run in the background, and
		# returns immediately.
		#
		# If the block takes an argument, it will be passed the
		# same id used to queue the work.
		#
		# The block may be preempted by a foreground job started in
		# this or another process. If not preempted, the block will
		# run in this process.
		def background(id, &block)
			@queue.background(id, &block)
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
		#
		# The block may wait on an already queued foreground job in
		# this or another process. If so queued, this block will not
		# run. If the block does run, it will run in this process.
		def foreground(id, &block)
			@queue.foreground(id, &block)
		end
	end
end

