module Indicators
	class RsiOneMinute
		def self.interval
			60
		end

		def self.indicator_id
			"RSI_1MIN"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time
			puts "FETCHING #{symbol_name} - #{self.indicator_id} - #{time}"
			truncated_time = Time.at((time.to_i / self.interval)*self.interval)
			ups = []
			downs = []
			previous_price = nil
			(0..13).each do |i|
				new_time = time - ((14-i)*self.interval)
				last_price = SymbolIndicator.collect_for(client_id, symbol_name, "LAST_PRICE_1MIN", new_time)
				
				if previous_price.present?
					delta = previous_price.value - last_price.value
					ups << delta if delta > 0
					downs << -delta if delta < 0
				end

				previous_price = last_price
			end
			ups_ratio = (ups.reduce(:+) || 0) / 14
			downs_ratio = (downs.reduce(:+) || 0) / 14
			rs = ups_ratio/downs_ratio
			rsi = 100 - (100 / (1+rs))

			SymbolIndicator.create!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: self.interval, interval_time: truncated_time, value: rsi)
		end
	end
end