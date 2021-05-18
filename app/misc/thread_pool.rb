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

	def check_availability
		@threads = @threads.delete_if{|e| !e.alive?}
		if @threads.length-1 < @size && @workers.length > 0
			worker = @workers.shift
			@threads << Thread.new(worker) {|worker|
				if worker.present?
					worker.perform
				end
				check_availability
			}
			if @restart && worker.present?
				@workers << worker
			end
		end
	end
end