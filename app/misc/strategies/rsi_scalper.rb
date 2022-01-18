module Strategies
	class RsiScalper

		def self.indicators
			[{indicator_id: 'RSI', interval: 1.minutes.to_i}]
		end

		def self.goal_factor
			return 1.003
		end

		def self.is_stale? wallet
			return false if wallet.client.get_available_cash(wallet) > calculate_order_amount(wallet)
			return false if wallet.purchase_tales.count == 0
			return wallet.purchase_tales.sort(updated_at: -1).first.updated_at < Time.now - 6.hours
		end

		def self.pick_stale_to_liquidate wallet
			prices = wallet.client.get_prices
			wallet.open_sales.collect{|t| {tale: t, price: prices.find{|p| p[:symbol_name] == t.symbol_name}[:price].to_f, loss_percentage: prices.find{|p| p[:symbol_name] == t.symbol_name}[:price].to_f / t.price}}.sort_by{|e| e[:loss_percentage]}.last
		end

		def self.calculate_order_amount wallet
			wallet_assets = wallet.client.get_assets wallet
			assets_value = wallet_assets.collect{|e| e[:value]}.reduce(:+)
			order_amount = [(assets_value / wallet.positions_quantity).round(2), 15].max
			return order_amount
		end

		def self.perform_purchase wallet
			tale = nil

			order_amount = calculate_order_amount wallet
			cash = wallet.client.get_available_cash wallet

			if cash > order_amount
				symbol_indicator = pick_symbol(wallet)
				
				if symbol_indicator.present?
					puts "RS - STARTING PURCHASE ATTEMPT"
					
					price = wallet.client.get_price(symbol_indicator.symbol_name)[:price]
					order = wallet.client.perform_market_buy(wallet, symbol_indicator.symbol_name, order_amount)

					price = order[:fills].last[:price].to_f
					tale = PurchaseTale.create!(wallet_id: wallet._id, symbol_name: symbol_indicator.symbol_name, price: price, buy_id: order[:orderId], buy_complete: true, asset_quantity: order[:executedQty], symbol_indicator: symbol_indicator.as_json.except!("_id"))

					remote_symbol = wallet.client.get_symbol(tale.symbol_name)
					quantity = wallet.client.get_assets(wallet).find{|e| e[:asset] == tale.symbol_name.gsub(wallet.base_coin,'')}[:free].to_f
					precision = (remote_symbol[:filters].find{|e| e[:filterType] == 'LOT_SIZE'}[:stepSize].split('.').last.index('1') || -1)+1
					quantity = quantity.floor(precision)
					precision = (remote_symbol[:filters].find{|e| e[:filterType] == 'PRICE_FILTER'}[:tickSize].split('.').last.index('1') || -1)+1
					goal = tale.goal(self.goal_factor).round(precision)
					order = wallet.client.perform_limit_sale(wallet, tale.symbol_name, quantity, "%.#{precision}f" % goal)

					tale.sale_id = order[:orderId]
					tale.save
					puts "RS - FINISHED PURCHASE - #{tale.symbol_name}"
				else
					puts "RS - NO GOOD TALE"
				end
			else
				puts "RS - NO MONEY LEFT"
			end
			return tale
		end

		def self.perform_sale wallet, tale
			puts "RS - AIN'T DOIN' DAT"
		end

		def self.pick_symbol wallet
			symbols = CryptoSymbol.symbols_for(wallet).to_a.shuffle

			symbols = symbols.each_with_index.collect do |symbol, i| 
				puts "#{i}/#{symbols.length} #{Time.now}"
				rsi = SymbolIndicator.collect_for(wallet.client_id, symbol.symbol_name, self.indicators.first[:indicator_id], Time.now, self.indicators.first[:interval])
				lp = SymbolIndicator.collect_for(wallet.client_id, symbol.symbol_name, self.indicators.last[:indicator_id], Time.now, self.indicators.last[:interval])
				llp = SymbolIndicator.collect_for(wallet.client_id, symbol.symbol_name, self.indicators.last[:indicator_id], Time.now - 1.minute, self.indicators.last[:interval])
				elegible = (rsi.value < 30 && lp.delta != 0 && llp.delta != 0)
				puts "ZF - ELEGIBLE? - #{rsi.symbol_name} - #{rsi.value} - #{lp.value} - #{llp.value} - #{llp.delta}- #{elegible}"

				return e if elegible
			end
			return nil
		end
	end
end