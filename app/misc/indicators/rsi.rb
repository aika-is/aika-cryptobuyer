module Indicators
	class Rsi
		
		def self.indicator_id
			"RSI"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time, interval
			truncated_time = Time.at((time.to_i / interval)*interval)
			truncated_time = truncated_time - interval if truncated_time + interval > Time.now
			puts "FETCHING #{symbol_name} - #{self.indicator_id} - #{time} - #{truncated_time}"
			ups = []
			downs = []
			previous_price = nil
			(0..13).each do |i|
				new_time = truncated_time - ((14-i)*interval)
				last_price = SymbolIndicator.collect_for(client_id, symbol_name, "LAST_PRICE", new_time, interval)
				
				if previous_price.present?
					delta = previous_price.value - last_price.value
					ups << delta if delta > 0
					downs << -delta if delta < 0
				end

				previous_price = last_price
			end
			ups_ratio = (ups.reduce(:+) || 0) / 14
			downs_ratio = (downs.reduce(:+) || 0) / 14
			downs_ratio = 1 if downs_ratio == 0
			rs = ups_ratio/downs_ratio
			rsi = 100 - (100 / (1+rs))

			s = SymbolIndicator.find_or_create_by!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: interval, interval_time: truncated_time)
			s.set(value: rsi)
			s
		end
	end
end