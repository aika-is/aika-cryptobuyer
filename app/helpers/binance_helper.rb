module BinanceHelper

	@ak = ENV['BNB_AK']
	@sk = ENV['BNB_SK']

	def get_symbols(not_in=[])
		response = RestClient.get("https://api.binance.com/api/v3/exchangeInfo")
		symbols = JSON.parse(response.body)

		symbols = symbols['symbols'].select{|e| e['quoteAsset'] == 'BUSD' && !not_in.include?(e['symbol'])}.collect{ |e| e['symbol'] }.shuffle
		return symbols
	end

	#-----
	def discover_symbols
		symbols = get_symbols()
		symbols.each do |e|
			CryptoSymbol.find_or_create_by(symbol: e)
		end
	end

end