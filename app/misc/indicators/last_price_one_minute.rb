module Indicators
	class LastPriceOneMinute
		def self.interval
			60
		end

		def self.indicator_id
			"LAST_PRICE_1MIN"
		end

		def self.fetch_symbol_indicator client_id, symbol_name, time
			from = Time.at((time.to_i / self.interval)*self.interval)
			to = from + self.interval
			price = (Wallet.client_for(client_id).get_trades symbol_name, from, to).last[:price]
			SymbolIndicator.create!(client_id: client_id, symbol_name: symbol_name, indicator_id: self.indicator_id, interval: self.interval, interval_time: from, value: price)
		end
	end
end