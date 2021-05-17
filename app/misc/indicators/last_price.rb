module Indicators
	class LastPrice

		def self.indicator_id
			"LAST_PRICE"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time, interval
			truncated_time = Time.at((time.to_i / interval)*interval)
			truncated_time = truncated_time - interval if truncated_time + interval > Time.now
			i = 0
			trades = []
			while trades.length == 0
				from = truncated_time-(i*interval)
				to = from + interval
				puts "FETCHING #{symbol_name} - #{self.indicator_id} - #{time} - #{from}"
				#puts "FROM #{symbol_name} - #{from}, #{to}"
				trades = Wallet.client_for(client_id).get_trades(symbol_name, from, to)
				i += 1
			end
			price = trades.last[:price]
			SymbolIndicator.create!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: interval, interval_time: from, value: price)
		end
	end
end