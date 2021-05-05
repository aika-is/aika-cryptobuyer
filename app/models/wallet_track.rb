class WalletTrack
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :value, type: Float

end