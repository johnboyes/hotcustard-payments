require 'sinatra'
require 'google/api_client'
require 'google_drive'
require 'pry'

GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS = ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS']
PRIVATE_KEY = ENV['PRIVATE_KEY']
SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
GOOGLE_API_VERSION = 'v2'

get '/' do
  client = Google::APIClient.new application_name: '[App name]', application_version: '1.0'
  private_key = OpenSSL::PKey::RSA.new PRIVATE_KEY, 'notasecret'
  client.authorization = Signet::OAuth2::Client.new(
    :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
    :audience => 'https://accounts.google.com/o/oauth2/token',
    :scope => 'https://www.googleapis.com/auth/drive https://spreadsheets.google.com/feeds/',
    :issuer => GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS,
    :signing_key => private_key)
  auth = client.authorization
  auth.fetch_access_token!
  session = GoogleDrive.login_with_oauth(auth.access_token)
  worksheet = session.spreadsheet_by_key(SPREADSHEET_KEY).worksheets[0]
  worksheet[2, 1]
end