class SymbolState
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :symbol_name, type: String
	field :price, type: Float
	field :max, type: Float
	field :min, type: Float
	field :goal, type: Float
	field :midpoint, type: Float
	field :matches, type: Integer
	field :good, type: Boolean, default: false

end