class CryptoSymbol
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :symbol_name, type: String
	field :client_ids, type: Array, default: []

	def self.register_symbol!(symbol_name, client_id)
		cs = CryptoSymbol.find_or_create_by!(symbol_name: symbol_name)
		cs.add_to_set(client_ids: client_id)
		return cs
	end

	def self.symbols_for(wallet)
		CryptoSymbol.where(client_ids: wallet.client_id)
	end
end