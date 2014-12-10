Gem::Specification.new {|s|
	s.name = 'throttle-queue'
	s.version = '0.1.0'
	s.licenses = ['MIT']
	s.summary = 'A thread-safe rate-limited work queue'
	s.description = 'A thread-safe rate-limited work queue, which allows for background and foreground operations.'
	s.homepage = 'https://github.com/theryan/throttle-queue'
	s.authors = ['Ryan Calhoun']
	s.email = ['ryanjamescalhoun@gmail.com']
	s.files = ['lib/throttle-queue.rb', 'lib/throttle-queue/single-process.rb', 'lib/throttle-queue/multi-process.rb', 'LICENSE.txt', 'README.md']
	s.test_files = ['test/throttle-queue-test.rb', 'test/multiprocess-test.rb', 'Rakefile']
}

