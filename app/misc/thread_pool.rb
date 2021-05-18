class ThreadPool

	def initialize(size = 2, restart = false)
		@size = size
		@threads = []
		@workers = []
		@pool_id = rand(999)
		@restart = restart
		@evicted = []
	end

	def append(worker)
		@workers << worker

		check_availability
	end

	def check_availability
		if @workers.length == 0 && @restart
			puts "RESTARTING"
			@workers = @workers + @evicted
		end
		@threads = @threads.delete_if{|e| !e.alive?}
		if @threads.length-1 < @size && @workers.length > 0
			@threads << Thread.new {
				worker = @workers.shift
				if worker.present?
					worker.perform
					@evicted << worker
				end
				check_availability
			}
		end
	end
end