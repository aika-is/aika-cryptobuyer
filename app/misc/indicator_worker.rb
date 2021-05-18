class IndicatorWorker

	def initialize(client_id, symbol_name, indicator_properties, time = nil
		@client_id = client_id
		@symbol_name = symbol_name
		@indicator_properties = indicator_properties
		@time = time
	end

	def perform()
		t = @time
		t ||= Time.now
		indicator = SymbolIndicator.collect_for(@client_id, @symbol_name, @indicator_properties[:indicator_id], t, @indicator_properties[:interval])
	end
end