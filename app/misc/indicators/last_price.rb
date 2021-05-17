module Indicators
	class LastPrice

		def self.indicator_id
			"LAST_PRICE"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time, interval
			truncated_time = Time.at((time.to_i / interval)*interval)
			truncated_time = truncated_time - interval if truncated_time + interval > Time.now
			i = 0
			price = nil
			trades = []
			from = truncated_time-(i*interval)
			to = from + interval
			trades = Wallet.client_for(client_id).get_trades(symbol_name, from, to)
			price = trades.last[:price] if trades.length > 0
			while !price.present?
				from = truncated_time-(i*interval)
				puts "FETCHING #{symbol_name} - #{self.indicator_id} - #{time} - #{from}"
				#puts "FROM #{symbol_name} - #{from}, #{to}"
				symbol = self.fetch_symbol_indicator client_id, symbol_name, from, interval
				price = symbol.value if symbol.present?
				i += 1
			end
			s = SymbolIndicator.find_or_create_by!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: interval, interval_time: from)
			s.set(value: price)
			s
		end
	end
end