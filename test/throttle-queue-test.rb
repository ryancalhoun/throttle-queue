require_relative '../lib/throttle-queue'
require 'test/unit'
require 'thread'

class ThrottleQueueTest < Test::Unit::TestCase

	def setup
		@t = ThrottleQueue.new 10
	end

	def teardown
		@t.shutdown
	end

	def testBackground
		results = []
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
			}
		}
		@t.wait
		assert_equal %w(Apple Banana Cake Donut Egg), results
	end
	def testForeground
		results = []
		%w(apple banana cake donut egg).each_with_index {|w,i|
			@t.foreground(w) {
				results << w.capitalize
			}
			assert_equal %w(Apple Banana Cake Donut Egg)[0..i], results
		}
		@t.wait
	end
	def testBackgroundInFlight
		results = []
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
				if w == 'banana'
					@t.background('banana') {
						results << 'BANANAYO'
					}
				end
			}
		}

		@t.wait
		assert_equal %w(Apple Banana Cake Donut Egg), results
	end
	def testBackgroundQueued
		results = []
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
				if w == 'banana'
					@t.background('cake') {
						results << 'CAKEYO'
					}
				end
			}
		}

		@t.wait
		assert_equal %w(Apple Banana Cake Donut Egg), results
	end
	def testForegroundInFlight
		results = []
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
				if w == 'banana'
					@t.foreground('banana') {
						results << 'BANANAYO'
					}
				end
			}
		}

		@t.wait
		assert_equal %w(Apple Banana Cake Donut Egg), results
	end
	def testForegroundQueued
		results = []

		t = Thread.new {
			Thread.stop
			@t.foreground('cake') {
				results << 'CAKEYO'
			}
		}
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
				if w == 'banana'
					t.run
				end
			}
		}

		@t.wait
		assert_equal %w(Apple Banana CAKEYO Donut Egg), results
	end
	def testForegroundPreemptBackground
		results = []

		t = Thread.new {
			Thread.stop
			%w(fish grape).each {|w|
				@t.foreground(w) {
					results << w.capitalize
				}
			}
		}
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
				if w == 'banana'
					t.run
				end
			}
		}

		@t.wait
		assert_equal %w(Apple Banana Fish Grape Cake Donut Egg), results
	end
	def testForegroundWaitOnQueuedForeground
		results = []
		threads = []

		ids = Queue.new
		ids << 'apple' << 'banana' << 'banana' << 'banana'

		values = Queue.new
		values << 'Apple' << 'Banana' << 'BANANAYO' << 'DUDE'

		ids.size.times {
			threads << Thread.new {
				@t.foreground(ids.pop) {
					results << values.pop
				}
			}
		}

		threads.each {|t|
			t.join
		}
		@t.wait
		assert_equal %w(Apple Banana), results
		assert_equal 0, ids.size
		assert_equal 2, values.size
	end
	def testShutdownWithoutWaiting
		results = []
		%w(apple banana cake donut egg).each {|w|
			@t.background(w) {
				results << w.capitalize
				if w == 'banana'
					@t.shutdown
				end
			}
		}
		@t.wait
		assert_equal %w(Apple Banana), results
	end

end
