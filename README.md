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

## Purpose

Sometimes server resources are rate-limited. If you as a client exceed the server's
limit, you become temporarily black-listed. A popular set of free APIs, which rhymes
with Foogle Maps, has strict limits in place after which you start seeing 403s instead
of 200s.

Let's say, for the above reason or another, you want to accumulate a cache of objects
no faster than N times a second. You're happy to startup your app quickly and let your
cache grow in the background. When a user requests a resource, you can bump it to the
front of your queue and block until it is ready.

## Usage

Create a queue and add background work

	require 'throttle-queue'

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

## Details

Each resource is assumed to have a unique identifier, e.g. a filename or a reproducible
hash value. The queue does not check if the resource exists first, but it will check if
the id has already been queued. If an id is already in the queue and the same id is
added as a background job, the block already in the queue is held onto; the new block is
dropped. If an id is in the background queue, adding it to the foreground will cause the
background block to be dropped. If an id is in the foreground queue, adding it again
from another thread will cause the new block to be dropped, and the existing block to be
waited upon.

Once an id has made it through the queue and been processed, the same id can be added
again and will be blindly processed again. It is assumed the user of the object knows
whether the resource already exists, and will decide whether or not a given id should be
added.

## Multiple Processes

Just bring in the multi-process-aware queue wrapper

	require 'throttle-queue/multi-process'

	q = ThrottleQueue::MultiProcess.new 3
	files.each {|file|
		q.background(file) {
			fetch file
		}
	}

Use this queue the same way in each process. Make sure each queue id has the same
meaning in each process (e.g. file paths should be absolute or relative to the same
working directory). If your processes race to stack up a bunch of background work, the
first process to add each work will be the only one to execute its block.

Do not fork after a multi-process queue is created. If your process forks itself,
create each queue after the fork.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

