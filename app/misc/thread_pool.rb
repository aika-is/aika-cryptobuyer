class ThreadPool

	def initialize(size = 2)
		@size = size
		@threads = []
		@workers = []
		@pool_id = rand(999)
	end

	def append(worker)
		@workers << worker

		check_availability
	end

	def check_availability
		puts "CHECKING AVAILABILITY - #{@pool_id}"
		@threads = @threads.delete_if{|e| !e.alive?}
		if @threads.length-1 < @size && @workers.length > 0
			@threads << Thread.new {
				worker = @workers.shift
				worker.perform
				check_availability
			}
		end
	end
end