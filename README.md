[![Gem Version](https://badge.fury.io/rb/throttle-queue.svg)](http://badge.fury.io/rb/throttle-queue)

# ThrottleQueue

	A thread-safe rate-limited work queue, with foreground and background operations

## Installation

Add this line to your application's Gemfile:

    gem 'throttle-queue'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install throttle-queue

## Usage

Create a queue and add background work

	q = ThrottleQueue.new 3
	files.each {|file|
		q.background(file) {
			fetch file
		}
	}

Get user input and take action right away

	q.foreground(user_file) {
		fetch user_file
	}

Wait for everything to finish

	q.wait

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
