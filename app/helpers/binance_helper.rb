module BinanceHelper

	def access_keys
		{ak: ENV['BNB_AK'], sk: ENV['BNB_SK']}
	end

	def get_symbols(not_in=[])
		response = RestClient.get("https://api.binance.com/api/v3/exchangeInfo")
		symbols = JSON.parse(response.body, symbolize_names: true)

		symbols = symbols[:symbols].select{|e| e[:quoteAsset] == 'BUSD' && !not_in.include?(e[:symbol])}.collect{ |e| e[:symbol] }.shuffle
		return symbols
	end

	def get_symbol(symbol_name)
		response = RestClient.get("https://api.binance.com/api/v3/exchangeInfo")
		symbols = JSON.parse(response.body, symbolize_names: true)

		symbol = symbols[:symbols].find{ |e| e[:symbol] == symbol_name }
		return symbol
	end

	def get_signature(params)
		key = access_keys[:sk]
		data = params.keys.collect{|e| "#{e}=#{params[e]}"}*'&'
		digest = OpenSSL::Digest.new('sha256')
		signature = OpenSSL::HMAC.hexdigest(digest, key, data)
		return signature
	end

	def get_wallet
		timestamp = Time.now.to_i*1000
		params = {timestamp: timestamp}
		params[:signature] = get_signature(params)
		response = RestClient.get("https://api.binance.com/api/v3/account", {params: params, 'X-MBX-APIKEY': access_keys[:ak]})
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

			puts "#{symbol_name}_#{from.to_s}_#{to.to_s} MISS"
			params = {symbol: symbol_name, endTime: to.to_i*1000, startTime: from.to_i*1000}
			response = RestClient.get("https://api.binance.com/api/v3/aggTrades", {params: params,'X-MBX-APIKEY': access_keys[:ak]})
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
					state.touch
					return state
				end
				maxes << trades_result[:max]
				min = [min, trades_result[:min]].min
				max = [max, trades_result[:max]].max
			end
		
			if maxes.length > 0
				goal = price * PurchaseTale.goalFactor
				midpoint = ((max-min)/2)+min
				matches = maxes.select{|e| e > goal}.length
				good = matches > (maxes.length / 2)

				
				state.set({symbol_name: symbol_name, max: max, min: min, price: price, goal: goal, midpoint: midpoint, good: good, matches: matches})
			end
		end
		state.touch

		return state
	end

	def get_available_cash
		wallet_assets = get_wallet_assets
		return wallet_assets.find{|e| e[:asset] == 'BUSD'}[:free].to_f
	end

	def perform_market_buy(symbol_name, current_order_amount)
		timestamp = Time.now.to_i*1000
		params = {symbol: symbol_name, side: 'BUY', type: 'MARKET', quoteOrderQty: current_order_amount, timestamp: timestamp}
		params[:signature] = get_signature(params)
		response = RestClient.post("https://api.binance.com/api/v3/order", params, {'X-MBX-APIKEY': access_keys[:ak]})
		return JSON.parse(response.body, symbolize_names: true)
	end

	def perform_limit_sale(symbol_name, quantity, price)
		timestamp = Time.now.to_i*1000
		params = {symbol: symbol_name, side: 'SELL', type: 'LIMIT', timeInForce: 'GTC', quantity: quantity, price: price, timestamp: timestamp}
		params[:signature] = get_signature(params)
		response = RestClient.post("https://api.binance.com/api/v3/order", params, {'X-MBX-APIKEY': access_keys[:ak]})
		return JSON.parse(response.body, symbolize_names: true)
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
		state = SymbolState.where(updated_at: {'$lt': Time.now - 9.minutes}).sort(updated_at: 1).first
		while(state.present?)
			calculate_symbol_state(state.symbol_name)
			state = SymbolState.where(updated_at: {'$lt': Time.now - 9.minutes}).sort(updated_at: 1).first
		end
	end

	def pick_symbol(not_in=[])
		prices = get_prices()
		state = nil
		while(state.nil?)
			state = SymbolState.where(good: true, symbol_name: {'$nin': not_in}).sort(matches: -1).first
			price = prices.find{|e| e[:symbol] == state.symbol_name}[:price].to_f
			if state.goal < price
				not_in << state.symbol_name
				state = nil
			end
		end
		return {state: state, price: price}
	end

	def order_purchase
		track = WalletTrack.all.sort(created_at: -1).first
		assets_value = track.value
		order_amount = [assets_value / 10, 10].max
		cash = get_available_cash
		if cash > order_amount
			assets = get_wallet_assets
			not_in = assets.select{|e| e[:locked].to_f > 0}.collect{|e| "#{e[:asset]}BUSD"}
			result = pick_symbol(not_in)
			state = result[:state]
			price = result[:price]
			factor = (cash / order_amount)
			if factor >= 1 && factor < 2
				current_order_amount = cash
			elsif factor >= 2
				current_order_amount = order_amount
			elsif factor < 1
				current_order_amount = 0
			end
			puts "BUY #{state.symbol_name}"
			puts "CASH #{cash}" 
			puts "PRICE #{price}" 
			puts "GOAL #{state.goal}" 
			puts "AMOUNT #{current_order_amount}" 
			puts state.to_json

			order = perform_market_buy(state.symbol_name, current_order_amount)
			puts order
			price = order[:fills].collect{|e| e[:price].to_f}.inject{|sum, e| sum + e}/order[:fills].length
			tale = PurchaseTale.create!(symbol_name: state.symbol_name, price: price, buy_id: order[:orderId], buy_complete: true, asset_quantity: order[:executedQty], state_snapshot: state.as_json)
			quantity = get_wallet_assets.find{|e| e[:asset] == tale.symbol_name.gsub('BUSD','')}[:free].to_f
			precision = (get_symbol(tale.symbol_name)[:filters].find{|e| e[:filterType] == 'LOT_SIZE'}[:stepSize].split('.').last.index('1') || -1)+1
			quantity = quantity.floor(precision)
			precision = (get_symbol(tale.symbol_name)[:filters].find{|e| e[:filterType] == 'PRICE_FILTER'}[:tickSize].split('.').last.index('1') || -1)+1
			goal = tale.goal.round(precision)
			order = perform_limit_sale(tale.symbol_name, quantity, goal)
			puts order
			tale.sale_id = order[:orderId]
			tale.save
		else
			puts "NO MONEY LEFT"
		end
	end	

end