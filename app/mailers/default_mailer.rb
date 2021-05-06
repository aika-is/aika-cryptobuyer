class DefaultMailer < ApplicationMailer

	def buy_email(message)
		@message = message
		mail(to: ENV['SMTP_TARGET'], subject: 'Cryptobuyer - Buy')
	end

end