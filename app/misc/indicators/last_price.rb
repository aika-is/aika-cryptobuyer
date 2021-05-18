module Indicators
	class LastPrice

		def self.indicator_id
			"LAST_PRICE"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time, interval
			truncated_time = Time.at((time.to_i / interval)*interval)
			truncated_time = truncated_time - interval if truncated_time + interval > Time.now
			price = nil
			trades = []
			s = SymbolIndicator.find_by(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: interval, interval_time: truncated_time)
			if s.nil? || s.value.nil?
				from = truncated_time
				to = from + interval
				trades = Wallet.client_for(client_id).get_trades(symbol_name, from, to)
				price = trades.last[:price] if trades.length > 0
				if !price.present?
					from = truncated_time-(interval)
					puts "FETCHING #{symbol_name} - #{self.indicator_id} - #{time} - #{from}"
					symbol = self.fetch_symbol_indicator client_id, symbol_name, from, interval
					price = symbol.value if symbol.present?
				end
				s = SymbolIndicator.find_or_create_by!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: interval, interval_time: truncated_time)
				s.value = price
				s.save
			end
			s
		end
	end
end