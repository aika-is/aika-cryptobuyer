class SymbolIndicator
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :client_id, type: String
	field :symbol_name, type: String

	field :indicator_id, type: String

	field :interval, type: Integer
	field :interval_time, type: Time
	
	field :value, type: Float

	field :ratio, type: Float
	field :delta, type: Float

	def value= val
		self[:value] = val
		previous = self.previous_indicator
		if previous.present?
			self.ratio = self.value / previous.value
			self.delta = self.value - previous.value
		end
	end

	def ascending?
		self.ratio > 1
	end

	def indicator
		return SymbolIndicator.fecth_indicator(self.indicator_name)
	end

	def previous_indicator force=false
		time = self.interval_time - self.interval		
		if force
			SymbolIndicator.collect_for(self.client_id, self.symbol_name, self.indicator_id, self.time)
		else
			SymbolIndicator.find_by(client_id: self.client_id, symbol_name: self.symbol_name, indicator_id: self.indicator_id, interval_time: time)
		end
	end

	def self.fetch_indicator indicator_id
		return Indicators::RsiOneMinute if indicator_id == 'RSI_1MIN'
		return Indicators::LastPriceOneMinute if indicator_id == 'LAST_PRICE_1MIN'
	end

	def self.collect_for(client_id, symbol_name, indicator_id, time)
		puts "COLLECTING #{symbol_name} - #{indicator_id} - #{time}"

		interval = SymbolIndicator.fetch_indicator(indicator_id).interval
		truncated_time = Time.at(((time.to_i / interval)*interval))
		truncated_time = truncated_time - interval if truncated_time + interval > Time.now
		symbol_indicator = SymbolIndicator.find_by(client_id: client_id, symbol_name: symbol_name, indicator_id: indicator_id, interval_time: truncated_time)
		if symbol_indicator.nil?
			symbol_indicator = SymbolIndicator.fetch_indicator(indicator_id).fetch_symbol_indicator client_id, symbol_name, time
		end
		return symbol_indicator
	end

end