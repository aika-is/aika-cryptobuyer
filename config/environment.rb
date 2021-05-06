# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!

ActionMailer::Base.smtp_settings = {
    :port           => ENV['SMTP_PORT'],
    :address        => ENV['SMTP_SERVER'],
    :user_name      => ENV['SMTP_LOGIN'],
    :password       => ENV['SMTP_PASSWORD'],
    :authentication => :plain,
}