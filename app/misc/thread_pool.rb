class ThreadPool

	def initialize(size = 2, restart = false)
		@size = size
		@threads = []
		@workers = []
		@restart = restart
		@semaphore = Mutex.new
	end

	def append(worker)
		@workers << worker

		check_availability
	end

	def launch_thread
		worker = @workers.shift
		if worker.present?
			@threads << Thread.new(worker) {|w|
				if w.present?
					begin
						w.perform
					rescue => e
						puts "ERROR IN THREAD"
						puts e.message
						puts e.backtrace
					end
				end
				@semaphore.synchronize {
					launch_thread
				}
			}
			if @restart
				@workers << worker
			end
		end
	end

	def check_availability
		@threads = @threads.delete_if{|e| !e.alive?}
		if @threads.length < @size
			@semaphore.synchronize {
				launch_thread
			}
		end
	end
end