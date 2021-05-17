require 'celluloid/current'

class IndicatorWorker
	include Celluloid

	def process_symbol_indicator(client_id, symbol_name, indicator_properties, time)
		puts "STARTING #{symbol_name}"
		indicator = SymbolIndicator.collect_for(client_id, symbol_name, indicator_properties[:indicator_id], time, indicator_properties[:interval])
		puts "FINISHING #{symbol_name}"
	end
end