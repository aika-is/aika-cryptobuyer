namespace :cryptobuyer do

	task :sanitize => :environment do
		include BinanceHelper
		discover_symbols
		track_value
		refresh_states
	end
end