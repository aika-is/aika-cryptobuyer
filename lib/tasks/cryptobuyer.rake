namespace :cryptobuyer do

	task :sanitize => :environment do
		WalletsProcessor.work_wallets Wallet.active, 10.minutes
	end
end