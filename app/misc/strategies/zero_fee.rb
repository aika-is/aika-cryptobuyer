module Strategies
	class ZeroFee

		def self.indicators
			[{indicator_id: 'RSI', interval: 1.minutes.to_i}]
		end

		def self.is_stale? wallet
			return false if wallet.client.get_available_cash(wallet) > calculate_order_amount(wallet)
			return false if wallet.purchase_tales.count == 0
			return wallet.purchase_tales.sort(updated_at: -1).first.updated_at < Time.now - 6.hours
		end

		def self.pick_stale_to_liquidate wallet
			prices = wallet.client.get_prices
			wallet.open_tales.collect{|t| {tale: t, price: prices.find{|p| p[:symbol_name] == t.symbol_name}[:price].to_f, loss_percentage: prices.find{|p| p[:symbol_name] == t.symbol_name}[:price].to_f / t.price}}.sort_by{|e| e[:loss_percentage]}.last
		end

		def self.calculate_order_amount wallet
			return 15
		end

		def self.perform_purchase wallet
			tale = nil

			order_amount = calculate_order_amount wallet
			cash = wallet.client.get_available_cash wallet

			if cash > order_amount
				symbol_indicator = pick_symbol(wallet)
				
				if symbol_indicator.present?
					puts "STARTING PURCHASE ATTEMPT"
					
					remote_symbol = wallet.client.get_symbol(symbol_indicator.symbol_name)
					price_precision = (remote_symbol[:filters].find{|e| e[:filterType] == 'PRICE_FILTER'}[:tickSize].split('.').last.index('1') || -1)+1
					quantity_precision = (remote_symbol[:filters].find{|e| e[:filterType] == 'LOT_SIZE'}[:stepSize].split('.').last.index('1') || -1)+1
					book_ticker = wallet.client.get_book_ticker(symbol_indicator.symbol_name)

					price = book_ticker[:askPrice].to_f-(1.0/(10**price_precision))
					quantity = (order_amount/price).floor(quantity_precision)

					order = wallet.client.perform_limit_buy(wallet, symbol_indicator.symbol_name, price, order_amount)

					tale = PurchaseTale.create!(wallet_id: wallet._id, symbol_name: symbol_indicator.symbol_name, price: price, buy_id: order[:orderId], buy_complete: false, asset_quantity: quantity, symbol_indicator: symbol_indicator.as_json.except!("_id"))

					remote_symbol = wallet.client.get_symbol(tale.symbol_name)
					quantity = wallet.client.get_assets(wallet).find{|e| e[:asset] == tale.symbol_name.gsub(wallet.base_coin,'')}[:free].to_f
					precision = (remote_symbol[:filters].find{|e| e[:filterType] == 'LOT_SIZE'}[:stepSize].split('.').last.index('1') || -1)+1
					quantity = quantity.floor(precision)
					precision = (remote_symbol[:filters].find{|e| e[:filterType] == 'PRICE_FILTER'}[:tickSize].split('.').last.index('1') || -1)+1
					goal = tale.goal(self.goal_factor).round(precision)
					order = wallet.client.perform_limit_sale(wallet, tale.symbol_name, quantity, "%.#{precision}f" % goal)

					tale.sale_id = order[:orderId]
					tale.save
					puts "FINISHED PURCHASE - #{tale.symbol_name}"
				else
					puts "NO GOOD TALE"
				end
			else
				puts "NO MONEY LEFT"
			end
			return tale
		end

		def self.pick_symbol wallet
			symbols = CryptoSymbol.symbols_for(wallet.client_id, wallet.excluded_symbols).to_a.shuffle

			symbols = symbols.each_with_index.collect do |symbol, i| 
				puts "#{i}/#{symbols.length} #{Time.now}"
				e = SymbolIndicator.collect_for(wallet.client_id, symbol.symbol_name, self.indicators.first[:indicator_id], Time.now, self.indicators.first[:interval])
				elegible = (e.value < 30 && e.delta != 0)
				puts "ELEGIBLE? - #{e.symbol_name} - #{e.value} - #{elegible}"

				return e if elegible
			end
			return nil
		end
	end
end