namespace :cryptobuyer do

	task :sanitize => :environment do
		include BinanceHelper
		discover_symbols
		refresh_states
		track_value
		order_purchase
	end
end