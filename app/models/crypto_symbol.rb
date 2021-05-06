class CryptoSymbol
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :symbol_name, type: String

end