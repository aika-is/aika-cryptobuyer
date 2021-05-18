class WalletsProcessor
	def self.work_wallets wallets, total_time
		max_loop = 0
		start = Time.now
		remaining = total_time
		wallets.each do |wallet|
			self.relaunch_wallet wallet
		end
		while remaining > max_loop
			wallets.each do |wallet|
				loop_start = Time.now

				self.sanitize_tales wallet
				self.check_staleness wallet
				self.discover_symbols wallet
				self.track_value wallet
				self.perform_purchases wallet

				loop_time = (Time.now - loop_start)
				max_loop = [max_loop, loop_time].max
				remaining = total_time - (Time.now - start)

				self.log("WALLET LOOP COMPLETE - Loop Time: #{loop_time} - Remaining: #{remaining}", {tags: ['CRYPTOBUYER', 'WALLET_LOOP', "ALIAS_#{wallet.alias}", "CLIENT_#{wallet.client_id}"]})

				return if remaining < max_loop
			end
		end
	end

	def self.heat_wallets wallets
		wallets.each do |wallet|
			self.relaunch_wallet wallet
		end
	end

	def self.relaunch_wallet wallet
		self.update_indicators wallet
	end

	def self.sanitize_tales wallet
		PurchaseTale.open_tales(wallet).each do |tale|
			if tale.sale_id.present?
				if !wallet.client.is_open_order?(wallet, tale.symbol_name, tale.sale_id)
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
			liquidation = wallet.strategy.pick_stale_to_liquidate wallet
			if liquidation.present?
				wallet.client.liquidate wallet, liquidation
				log("WALLET STALENESS DETECTED", {tags: ['CRYPTOBUYER', 'WALLET_LOOP', "ALIAS_#{wallet.alias}", "STRATEGY_#{wallet.strategy_id}"]}, {liquidation: liquidation})
			else
				log("WALLET STALENESS DETECTED - BUT NOTHING TO LIQUIDATE", {tags: ['CRYPTOBUYER', 'WALLET_LOOP', "ALIAS_#{wallet.alias}", "STRATEGY_#{wallet.strategy_id}"]})
			end
		else

		end
	end

	def self.discover_symbols wallet
		symbols = wallet.client.get_symbols(wallet).collect{|e| e[:symbol]}

		symbols.each do |symbol|
			CryptoSymbol.register_symbol!(wallet.client_id, symbol)
		end
		CryptoSymbol.deregister_not_in_symbols!(wallet.client_id, symbols)
	end

	def self.update_indicators wallet
		pool = ThreadPool.new(3, true)
		wallet.strategy.indicators.each do |indicator_properties|
			CryptoSymbol.symbols_for(wallet.client_id).each do |symbol|
				puts "APPENDING #{symbol.symbol_name}"
				pool.append(IndicatorWorker.new(wallet.client_id, symbol.symbol_name, indicator_properties))
			end
		end
	end

	def self.track_value wallet
		wallet_assets = wallet.client.get_assets wallet
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