namespace :cryptobuyer do

	task :sanitize => :environment do
		include BinanceHelper
		order_purchase
		discover_symbols
		track_value
		refresh_states
	end
end