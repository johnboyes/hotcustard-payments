require 'sinatra'
require 'google/api_client'
require 'google_drive'
require 'pry'

CLIENT_ID = ENV['CLIENT_ID']
PRIVATE_KEY = ENV['PRIVATE_KEY']
GOOGLE_API_VERSION = 'v2'

get '/' do
  client = Google::APIClient.new application_name: '[App name]', application_version: '1.0'
  key = OpenSSL::PKey::RSA.new PRIVATE_KEY, 'notasecret'
  client.authorization = Signet::OAuth2::Client.new(
  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
  :audience => 'https://accounts.google.com/o/oauth2/token',
  :scope => 'https://www.googleapis.com/auth/drive https://spreadsheets.google.com/feeds/',
  :issuer => CLIENT_ID,
  :signing_key => key)
  auth = client.authorization
  session = GoogleDrive.login_with_oauth(auth.access_token)
  "looks good, tastes good"
end