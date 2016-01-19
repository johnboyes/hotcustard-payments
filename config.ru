require 'rubygems'
require 'bundler'

Bundler.require

use Rack::Session::Cookie, :secret => 'abc123'

use OmniAuth::Builder do
  provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET']
end

require './hot-custard.rb'
run HotCustardApp