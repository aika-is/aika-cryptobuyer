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

	def self.symbols_for(wallet)
		CryptoSymbol.where(client_ids: wallet.client_id, symbol_name: {'$nin': wallet.excluded_symbols}).sort(symbol_name: 1).filter{|e| e.symbol_name.index(wallet.base_coin).present? && e.symbol_name.index(wallet.base_coin) + wallet.base_coin.length == e.symbol_name.length}
	end

	def self.deregister_not_in_symbols!(wallet)
		CryptoSymbol.where(symbol_name: {'$in': wallet.excluded_symbols}, client_ids: wallet.client_id).update_all({'$pull': {client_ids: wallet.client_id}})
	end
end