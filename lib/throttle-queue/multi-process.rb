require 'drb'
require 'fileutils'
require_relative 'single-process.rb'

class ThrottleQueue
	class MultiProcess
		def initialize(limit, name = 'ThrottleQueue')
			tmp = "/tmp/#{name}.sock"
			FileUtils.touch tmp
			File.open(tmp, 'r+') {|f|
				f.flock File::LOCK_EX
				begin
					port = f.read.to_i
					if port == 0
						@queue = ThrottleQueue.new(limit)
						@drb = DRb.start_service nil, @queue
						f.seek 0, IO::SEEK_SET
						f.truncate 0
						f.write @drb.uri[/\d+$/]
						f.flock File::LOCK_UN
					else
						@queue = DRbObject.new_with_uri("druby://localhost:#{port}")
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
		def shutdown
			@queue.shutdown
			@drb.stop_service if @drb
		end
		def idle?
			@queue.idle?
		end
		def wait(timeout = nil)
			begin
				@queue.wait(timeout)
			rescue DRb::DRbConnError
			end
		end
		def background(id, &block)
			@queue.background(id, &block)
		end
		def foreground(id, &block)
			@queue.foreground(id, &block)
		end
	end
end

