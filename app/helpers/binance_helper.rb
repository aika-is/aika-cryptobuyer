module BinanceHelper

	def keys
		{ak: ENV['BNB_AK'], sk: ENV['BNB_SK']}
	end

	def get_symbols(not_in=[])
		response = RestClient.get("https://api.binance.com/api/v3/exchangeInfo")
		symbols = JSON.parse(response.body, symbolize_names: true)

		symbols = symbols[:symbols].select{|e| e[:quoteAsset] == 'BUSD' && !not_in.include?(e[:symbol])}.collect{ |e| e[:symbol] }.shuffle
		return symbols
	end

	def get_signature(params)
		key = keys[:sk]
		data = params.to_query
		digest = OpenSSL::Digest.new('sha256')
		signature = OpenSSL::HMAC.hexdigest(digest, key, data)
		return signature
	end

	def get_wallet
		timestamp = Time.now.to_i*1000
		params = {timestamp: timestamp}
		params[:signature] = get_signature(params)
		response = RestClient.get("https://api.binance.com/api/v3/account", {params: params, 'X-MBX-APIKEY': @ak})
		return JSON.parse(response.body, symbolize_names: true)
	end

	def get_prices
		response = RestClient.get("https://api.binance.com/api/v3/ticker/price")
		return JSON.parse(response.body, symbolize_names: true)
	end

	def get_wallet_assets
		wallet = get_wallet
		prices = get_prices
		wallet_assets = wallet[:balances].select{|e| (e[:free].to_f + e[:locked].to_f) > 0}.collect{|e| e.merge({amount: (e[:free].to_f + e[:locked].to_f), price: (prices.find{|p| p[:symbol] == "#{e[:asset]}BUSD"} || {price: 1})[:price].to_f})}.collect{|e| e.merge({value: e[:amount] * e[:price]})}
		return wallet_assets
	end

	#-----
	def discover_symbols
		symbols = get_symbols()
		symbols.each do |e|
			CryptoSymbol.find_or_create_by(symbol: e)
		end
	end

	def track_value
		wallet_assets = get_wallet_assets
		wallet_value = wallet_assets.collect{|e| e[:value]}.inject{|sum, e| sum + e}
		WalletTrack.create!(value: wallet_value)
	end

end