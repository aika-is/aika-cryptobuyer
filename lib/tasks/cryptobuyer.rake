namespace :cryptobuyer do

	task :sanitize => :environment do
		WalletsProcessor.work_wallets Wallet.all, 10.minutes
	end
end