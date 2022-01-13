class PurchaseTale
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :wallet_id, type: String

	field :symbol_name, type: String
	field :price, type: Float

	field :buy_id, type: Integer
	field :buy_complete, type: Boolean, default: false
	field :buy_at, type: Time, default: Time.now

	field :asset_quantity, type: Float

	field :sale_id, type: Integer
	field :sale_completed, type: Boolean, default: false
	field :sale_at, type: Time

	field :open_duration, tupe: Integer

	field :symbol_indicator, type: Hash

	field :liquidated, type: Boolean, default: false	

	def goal
		return price * PurchaseTale.goalFactor
	end

	def self.stale_buys
		self.where(buy_complete: false, buy_at: {'$lt': Time.now - 1.minute})
	end

	def self.goalFactor
		return 1.01061
	end

	def self.open_tales wallet
		self.where(wallet_id: wallet._id, sale_completed: false)
	end
end