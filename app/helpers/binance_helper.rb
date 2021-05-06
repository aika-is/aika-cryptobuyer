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
		response = RestClient.get("https://api.binance.com/api/v3/account", {params: params, 'X-MBX-APIKEY': keys[:ak]})
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

	def fetch_trades symbol_name, from, to
		Rails.cache.fetch("#{symbol_name}_#{from.to_s}_#{to.to_s}", expires_in: 24.hours) do

			puts "#{symbol_name}_#{symbol_name.to_s}_#{to.to_s} MISS"
			params = {symbol: symbol_name, endTime: to.to_i*1000, startTime: from.to_i*1000}
			response = RestClient.get("https://api.binance.com/api/v3/aggTrades", {params: params,'X-MBX-APIKEY': keys[:ak]})
			trades = JSON.parse(response.body, symbolize_names: true)
			trade_results = nil
			if trades.length > 0
				trade_results =  collect_trades(trades)
			end
			trade_results
		end
	end

	def collect_trades(trades)
		price  = trades.first[:p].to_f
		sample = trades.length
		prices = trades.sample(sample).collect{|e| e[:p].to_f}
		_min = prices.min
		_max = prices.max
		return {price: price, min: _min, max: _max}
	end

	def calculate_symbol_state(symbol_name)
		window = 60*15
		max = 0
		min = 999999999999999999999
		avgs = []
		maxes = []
		price = nil
		state = SymbolState.find_or_create_by(symbol_name: symbol_name)

		to = Time.now
		from = Time.at((Time.now.to_i / window)*window)
		trades_result = fetch_trades symbol_name, from, to

		if trades_result.present?
			price = trades_result[:price]
			maxes << trades_result[:max]
			min = trades_result[:min]
			max = trades_result[:max]

			(0..(24*4)).to_a.each do |i|
				to = Time.at(((Time.now - (window*i)).to_i / window)*window)
				from = Time.at(((Time.now - (window*(i+1))).to_i / window)*window)
				trades_result = fetch_trades symbol_name, from, to
				if trades_result.blank?
					puts "break"
					break
				end
				maxes << trades_result[:max]
				min = [min, trades_result[:min]].min
				max = [max, trades_result[:max]].max
			end
		
			if maxes.length > 0
				goal = price * 1.01061
				midpoint = ((max-min)/2)+min
				matches = maxes.select{|e| e > goal}.length
				good = matches > (maxes.length / 2)

				
				state.set({symbol_name: symbol_name, max: max, min: min, price: price, goal: goal, midpoint: midpoint, good: good, matches: matches})
			end
		end

		return state
	end

	#-----
	def discover_symbols
		symbols = get_symbols()
		symbols.each do |e|
			CryptoSymbol.find_or_create_by(symbol_name: e)
		end
	end

	def track_value
		wallet_assets = get_wallet_assets
		wallet_value = wallet_assets.collect{|e| e[:value]}.inject{|sum, e| sum + e}
		WalletTrack.create!(value: wallet_value)
	end

	def refresh_states
		missing_symbols = CryptoSymbol.where(symbol_name: {'$nin': SymbolState.all.collect{|e| e.symbol_name}})
		missing_symbols.each do |e|
			calculate_symbol_state(e.symbol_name)
		end
	end

end