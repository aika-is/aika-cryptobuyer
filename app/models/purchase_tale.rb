class PurchaseTale
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :symbol_name, type: String
	field :price, type: Float

	field :buy_id, type: Integer
	field :buy_complete, type: Boolean, default: false
	field :buy_at, type: Time

	field :sale_id, type: Integer
	field :sale_completed, type: Boolean, default: false

	def goal
		return price * self.goalFactor
	end

	def self.stale_buys
		self.where(buy_complete: false, buy_at: {'$lt': Time.now - 1.minute})
	end

	def self.goalFactor
		return 1.01061
	end
end