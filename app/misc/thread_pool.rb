class ThreadPool

	def initialize(size = 2, restart = false)
		@size = size
		@threads = []
		@workers = []
		@restart = restart
	end

	def append(worker)
		@workers << worker

		check_availability
	end

	def launch_thread
		worker = @workers.shift
		if worker.present?
			@threads << Thread.new(worker) {|worker|
				if worker.present?
					worker.perform
				end
				launch_thread
			}
			if @restart
				@workers << worker
			end
		end
	end

	def check_availability
		@threads = @threads.delete_if{|e| !e.alive?}
		if @threads.length < @size
			launch_thread
		end
	end
end