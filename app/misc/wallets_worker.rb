class WalletsWorker
	def self.work_wallets wallets, total_time
		max_loop = 0
		start = Time.now
		wallets.each do |wallet|
			loop_start = Time.now

			sanitize_tales wallet
			check_staleness wallet
			discover_symbols wallet
			update_indicators wallet
			track_value wallet

			loop_time = (Time.now - loop_start)
			max_loop = [max_loop, loop_time].max
			remaining = total_time - (Time.now - start)

			log("WALLET LOOP COMPLETE - Loop Time: #{loop_time} - Remaining: #{remaining}", {tags: ['CRYPTOBUYER', 'WALLET_LOOP', "ALIAS_#{wallet.alias}", "CLIENT_#{wallet.exchange_client_id}"]})

			return if remaining < max_loop
		end
	end

	def self.sanitize_tales wallet
		PurchaseTale.open_tales(wallet).each do |tale|
			if tale.sale_id.present?
				if !is_open_order?(wallet, tale.symbol_name, tale.sale_id)
					tale.sale_completed = true
					tale.save
				end
			else
				tale.sale_completed = true
				tale.save
			end
		end
	end

	def self.check_staleness wallet
		if wallet.strategy.is_stale? wallet
			liquidation = pick_stale_to_liquidate wallet
			wallet.client.liquidate wallet, liquidation
			log("WALLET STALENESS DETECTED", {tags: ['CRYPTOBUYER', 'WALLET_LOOP', "ALIAS_#{wallet.alias}", "STRATEGY_#{wallet.bidding_stategy_id}"]}, {liquidation: liquidation})
		else

		end
	end

	def self.discover_symbols wallet
		symbols = wallet.client.get_symbols wallet
		symbols.each do |symbol_name|
			CryptoSymbol.register_symbol!(symbol_name, wallet.client_id)
		end
	end

	def self.update_indicators wallet
		wallet.strategy.indicators.each do |indicator_id|
			CryptoSymbol.symbols_for(wallet).each do |symbol|
				indicator = SymbolIndicator.collect_for(wallet.client_id, symbol.symbol_name, indicator_id, Time.now)
			end
		end
	end

	def self.track_value wallet
		wallet_assets = get_assets wallet
		wallet_value = wallet_assets.collect{|e| e[:value]}.reduce(:+)
		WalletTrack.create!(wallet_id: wallet._id, value: wallet_value)
	end

	def self.perform_purchases wallet
		loop do
			tale = wallet.strategy.perform_purchase wallet
			break if tale.nil?
		end
	end

	def self.log message, options
		puts message
	end

end