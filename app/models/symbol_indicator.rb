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
		self.redelta!
	end

	def redelta!
		previous = self.previous_indicator
		if previous.present?
			self.set(ratio: self.value / previous.value)
			self.set(delta: self.value - previous.value)
		end
	end

	def ratio
		if self[:ratio].nil?
			puts "MISSING RATIO"

			previous = self.previous_indicator true
			self.redelta!
		end
		return self[:ratio]
	end

	def delta
		if self[:delta].nil?
			puts "MISSING DELTA"
			
			previous = self.previous_indicator true
			self.redelta!
		end
		return self[:delta]
	end

	def ascending?
		self.ratio > 1
	end

	def indicator
		return SymbolIndicator.fecth_indicator(self.indicator_id)
	end

	def previous_indicator force=false
		time = self.interval_time - self.interval		
		symbol = SymbolIndicator.find_by(client_id: self.client_id, symbol_name: self.symbol_name, indicator_id: self.indicator_id, interval_time: time, interval: self.interval)
		if force && symbol.nil?
			symbol = SymbolIndicator.collect_for(self.client_id, self.symbol_name, self.indicator_id, self.time, self.interval)
		end
		return symbol
	end

	def self.fetch_indicator indicator_id
		return Indicators::Rsi if indicator_id == 'RSI'
		return Indicators::LastPrice if indicator_id == 'LAST_PRICE'
	end

	def self.collect_for(client_id, symbol_name, indicator_id, time, interval)
		puts "COLLECTING #{symbol_name} - #{indicator_id} - #{time}"
		truncated_time = Time.at(((time.to_i / interval)*interval))
		truncated_time = truncated_time - interval if truncated_time + interval > Time.now
		symbol_indicator = SymbolIndicator.find_by(client_id: client_id, symbol_name: symbol_name, indicator_id: indicator_id, interval_time: truncated_time, interval: interval)
		if symbol_indicator.nil?
			symbol_indicator = SymbolIndicator.fetch_indicator(indicator_id).fetch_symbol_indicator client_id, symbol_name, time, interval
		end
		return symbol_indicator
	end

end