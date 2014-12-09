require_relative '../lib/throttle-queue/multi-process'
require 'test/unit'
require 'thread'

class ThrottleQueueMultiProcessTest < Test::Unit::TestCase

	def testSingleProcess
		t = ThrottleQueue::MultiProcess.new 10

		results = []
		%w(apple banana cake donut egg).each {|w|
			t.background(w) {
				results << w.capitalize
			}
		}
		t.wait
		assert_equal %w(Apple Banana Cake Donut Egg), results
	ensure
		t.shutdown
	end

	def testTwoProcesses
		p = fork {
			t = ThrottleQueue::MultiProcess.new 10
			%w(fig grape ham ice jelly).each {|w|
				t.background(w) {
					File.open('results.txt', 'a') {|f|
						f.puts w.capitalize
					}
				}
			}
			t.wait
		}

		t = ThrottleQueue::MultiProcess.new 10

		results = []
		%w(apple banana cake donut egg).each {|w|
			t.background(w) {
				results << w.capitalize
			}
		}
		t.wait
		assert_equal %w(Apple Banana Cake Donut Egg), results
		assert_equal %w(Fig Grape Ham Ice Jelly), File.open('results.txt') {|f| f.readlines.map &:chomp}
	ensure
		t.shutdown
		FileUtils.rm_f 'results.txt'
	end

	def testTwoProcessesWithFG
		rd, wr = IO.pipe

		p = fork {
			rd.close
			t = ThrottleQueue::MultiProcess.new 10
			%w(fig grape ham ice jelly).each {|w|
				t.background(w) {
					File.open('results.txt', 'a') {|f|
						f.puts w.capitalize
						if w == 'grape'
							wr.close
						end
					}
				}
			}
			t.wait
		}

		wr.close

		t = ThrottleQueue::MultiProcess.new 10
		rd.read
		rd.close

		t.foreground('apple') {|w|
			File.open('results.txt', 'a') {|f|
				f.puts w.capitalize
			}
		}

		t.wait
		assert_equal %w(Fig Grape Apple Ham Ice Jelly), File.open('results.txt') {|f| f.readlines.map &:chomp}
	ensure
		t.shutdown
		FileUtils.rm_f 'results.txt'
	end
end
