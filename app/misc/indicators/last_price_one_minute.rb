module Indicators
	class LastPriceOneMinute
		def self.interval
			60
		end

		def self.indicator_id
			"LAST_PRICE_1MIN"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time
			puts "FETCHING #{symbol_name} - #{self.indicator_id} - #{time}"
			i = 0
			trades = []
			while(trades.length == 0)
				from = Time.at((time.to_i / self.interval)*self.interval)-(i*self.interval)
				to = from + self.interval
				trades = Wallet.client_for(client_id).get_trades symbol_name, from, to
				i++
			end
			price = trades.last[:price]
			SymbolIndicator.create!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: self.interval, interval_time: from, value: price)
		end
	end
end