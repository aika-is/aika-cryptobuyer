class Wallet
	include Mongoid::Document
	include Mongoid::Timestamps
	include EncryptionHelper

	field :client_id, type: String
	field :alias, type: String

	field :base_coin, type: String
	field :positions_quantity, type: Integer
	field :strict_amounts, type: Boolean, default: true

	field :encrypted_ak, type: String
	field :encrypted_sk, type: String

	field :inner_key, type: String, default: SecureRandom.hex(6)

	field :strategy_id, type: String

	def ak
		decrypt_text(self.inner_key, self.encrypted_ak)
	end

	def sk
		decrypt_text(self.inner_key, self.encrypted_sk)
	end

	def ak= value
		self.encrypted_ak = encrypt_text(self.inner_key, value)
	end

	def sk= value
		self.encrypted_sk = encrypt_text(self.inner_key, value)
	end

	def client
		Wallet.client_for self.client_id
	end

	def strategy
		Wallet.strategy_for self.strategy_id
	end

	def self.client_for client_id
		return Clients::BinanceClient if client_id == 'BINANCE'
	end

	def self.strategy_for strategy_id
		return Strategies::RsiScalper if strategy_id == 'RSI_SCALPER'
	end
end