module Indicators
	class LastPriceOneMinute
		def self.interval
			60
		end

		def self.indicator_id
			"LAST_PRICE_1MIN"
		end

		def self.fetch_symbol_indicator wallet, symbol_name, time
			from = Time.at((time.to_i / self.interval)*self.interval)
			to = from + self.interval
			price = (wallet.client.get_trades symbol_name, from, to).last[:price]
			SymbolIndicator.create!(client_id: wallet.client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: self.interval, interval_time: truncated_time, value: price)
		end
	end
end