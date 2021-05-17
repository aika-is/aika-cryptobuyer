namespace :cryptobuyer do

	task :sanitize => :environment do
		#include BinanceHelper
		#sanitize_tales
		#revive_account
		#discover_symbols
		#refresh_states
		#track_value
		#order_purchase
		WalletsProcessor.work_wallets Wallet.all, 10.minutes
	end
end