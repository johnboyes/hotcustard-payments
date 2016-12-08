require 'rubygems'
require 'bundler'

Bundler.require

use Rack::Session::Cookie, secret: 'abc123'

use OmniAuth::Builder do
  provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET']
end

# Redirect to failure page on authentication failure, instead of raising an exception
OmniAuth.config.on_failure = proc do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end

require './hot_custard_payments.rb'
run HotCustardApp
