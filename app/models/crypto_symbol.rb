class CryptoSymbol
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :symbol_name, type: String
	field :client_ids, type: Array, default: []

	def self.register_symbol!(client_id, symbol_name)
		cs = CryptoSymbol.find_or_create_by!(symbol_name: symbol_name)
		cs.add_to_set(client_ids: client_id)
		return cs
	end

	def self.symbols_for(client_id)
		CryptoSymbol.where(client_ids: client_id)
	end

	def self.deregister_not_in_symbols!(client_id, symbols)
		CryptoSymbol.where(symbol_name: {'$nin': symbols}, client_ids: client_id).update_all({'$pull': {client_ids: 'client_id'}})
	end
end