class CryptoSymbol
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :symbol, type: String

end