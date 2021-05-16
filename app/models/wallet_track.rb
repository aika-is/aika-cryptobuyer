class WalletTrack
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :wallet_id, type: String	
	field :value, type: Float

end