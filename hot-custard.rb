require 'sinatra'
require 'google/api_client'

CLIENT_ID = ENV['CLIENT_ID']
PRIVATE_KEY = ENV['PRIVATE_KEY']

get '/' do

puts PRIVATE_KEY
client = Google::APIClient.new application_name: '[App name]', application_version: '1.0'
key = OpenSSL::PKey::RSA.new PRIVATE_KEY, 'notasecret'
client.authorization = Signet::OAuth2::Client.new(
  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
  :audience => 'https://accounts.google.com/o/oauth2/token',
  :scope => 'https://spreadsheets.google.com/feeds/',
  :issuer => CLIENT_ID,
  :signing_key => key)
client.authorization.fetch_access_token!

  "looks good, tastes good"
end