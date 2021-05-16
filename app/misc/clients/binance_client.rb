module Clients
	class BinanceClient

		def self.get_symbols(wallet=nil, not_in=[])
			response = RestClient.get("https://api.binance.com/api/v3/exchangeInfo")
			symbols = JSON.parse(response.body, symbolize_names: true)

			symbols = symbols[:symbols]
			if wallet.present?
				symbols = symbols.select{|e| e[:quoteAsset] == wallet.base_coin && !not_in.include?(e[:symbol]) && e[:status] == 'TRADING'}.collect{ |e| e[:symbol] }
			end
			return symbols
		end

		def self.get_symbol symbol_name
			self.get_symbols.select{|e| e[:symbol_name] == symbol_name}
		end

		def self.get_prices
			response = RestClient.get("https://api.binance.com/api/v3/ticker/price")
			return JSON.parse(response.body, symbolize_names: true).collect{|e| {symbol_name: e[:symbol], price: e[:price]}}
		end

		def self.get_price symbol_name
			self.get_prices.find{|e| e[:symbol_name] == symbol_name}
		end

		def self.get_trades symbol_name, from, to
			params = {symbol: symbol_name, endTime: to.to_i*1000, startTime: from.to_i*1000}
			response = RestClient.get("https://api.binance.com/api/v3/aggTrades", {params: params})
			trades = JSON.parse(response.body, symbolize_names: true)
			trades.collect{|e| {price: e[:p].to_f, quantity: e[:q].to_f, time: Time.at(e[:T]/1000)}}.reverse
		end

		def self.get_assets wallet
			timestamp = Time.now.to_i*1000
			params = {timestamp: timestamp}
			params[:signature] = self.get_signature(params)
			response = RestClient.get("https://api.binance.com/api/v3/account", {params: params, 'X-MBX-APIKEY': wallet.ak})
			assets = JSON.parse(response.body, symbolize_names: true)[:balances]

			prices = self.get_prices
			return assets.select{|e| (e[:free].to_f + e[:locked].to_f) > 0}.collect{|e| e.merge({amount: (e[:free].to_f + e[:locked].to_f), price: (prices.find{|p| p[:symbol] == "#{e[:asset]}BUSD"} || {price: 1})[:price].to_f})}.collect{|e| e.merge({value: e[:amount] * e[:price]})}
		end

		def self.get_positioned_assets wallet
			self.get_assets.select{|e| e[:locked].to_f > 0}
		end

		def self.get_available_cash wallet
			wallet_assets = get_assets wallet
			return wallet_assets.find{|e| e[:asset] == wallet.base_coin}[:free].to_f
		end

		def self.get_order wallet, symbol_name, order_id
			timestamp = Time.now.to_i*1000
			params = {symbol: symbol_name, orderId: order_id, timestamp: timestamp}
			params[:signature] = get_signature(wallet, params)
			response = RestClient.get("https://api.binance.com/api/v3/order", {params: params, 'X-MBX-APIKEY': wallet.ak})
			return JSON.parse(response.body, symbolize_names: true)
		end

		def self.cancel_order wallet, symbol_name, order_id
			timestamp = Time.now.to_i*1000
			params = {symbol: symbol_name, orderId: order_id, timestamp: timestamp}
			params[:signature] = get_signature(wallet, params)
			response = RestClient.delete("https://api.binance.com/api/v3/order", {params: params, 'X-MBX-APIKEY': wallet.ak})
			return JSON.parse(response.body, symbolize_names: true)
		end

		def self.is_open_order? wallet, symbol_name, order_id
			order = get_order(tale.symbol_name, tale.sale_id)
			return ['FILLED', 'CANCELED'].include?(order[:status])
		end

		def self.perform_limit_sale(wallet, symbol_name, quantity, price)
			timestamp = Time.now.to_i*1000
			params = {symbol: symbol_name, side: 'SELL', type: 'LIMIT', timeInForce: 'GTC', quantity: quantity, price: price, timestamp: timestamp}
			params[:signature] = get_signature(wallet, params)
			response = RestClient.post("https://api.binance.com/api/v3/order", params, {'X-MBX-APIKEY': wallet.ak})
			return JSON.parse(response.body, symbolize_names: true)
		end

		def self.perform_market_buy(wallet, symbol_name, current_order_amount)
			timestamp = Time.now.to_i*1000
			params = {symbol: symbol_name, side: 'BUY', type: 'MARKET', quoteOrderQty: current_order_amount, timestamp: timestamp}
			params[:signature] = get_signature(params)
			begin
				response = RestClient.post("https://api.binance.com/api/v3/order", params, {'X-MBX-APIKEY': wallet.ak})
			rescue => e
				puts params
				puts e.message
				puts e.response.body
				raise e
			end
			return JSON.parse(response.body, symbolize_names: true)
		end

		def self.get_signature(wallet, params)
			key = wallet.sk
			data = params.keys.collect{|e| "#{e}=#{params[e]}"}*'&'
			digest = OpenSSL::Digest.new('sha256')
			signature = OpenSSL::HMAC.hexdigest(digest, key, data)
			return signature
		end

		def self.liquidate wallet, liquidation
			tale = liquidation[:tale]
			price = liquidation[:price]
			
			order = get_order tale.symbol_name, tale.sale_id
			cancel_order tale.symbol_name, tale.sale_id
			quantity = order[:origQty].to_f - order[:executedQty].to_f
			order = perform_limit_sale(wallet, tale.symbol_name, quantity, price)

			tale.liquidated = true
			tale.save

			return tale
		end

	end
end