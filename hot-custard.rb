require 'sinatra/base'
require "sinatra/cookies"
require 'google/api_client'
require 'google_drive'
require 'koala'
require 'pry'
require_relative 'lib/cache'
require 'redis'

class HotCustardApp < Sinatra::Base

$stdout.sync = true #so we can see stdout when starting with foreman, see https://github.com/ddollar/foreman/wiki/Missing-Output

GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS = ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS']
PRIVATE_KEY = ENV['PRIVATE_KEY']
SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
FACEBOOK_APP_ID = ENV['FACEBOOK_APP_ID']
FACEBOOK_APP_SECRET = ENV['FACEBOOK_APP_SECRET']
FACEBOOK_CALLBACK_URL = nil
GOOGLE_API_VERSION = 'v2'

def self.cache
  @@cache ||= Mu::Cache.new :max_size => 1024, :max_time => 72000.0
end

helpers do
  def current_user
    !session[:uid].nil?
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  redirect to('/auth/facebook') unless current_user
end

get '/payments' do
  @person = logged_in_user
  @transactions = individual_transactions_for_logged_in_user transactions_worksheet
  @balance = individual_balances_for_logged_in_user
  erb :transactions
end

def worksheet name, session
  google_session.spreadsheet_by_key(SPREADSHEET_KEY).worksheet_by_title name
end

def google_session
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
  GoogleDrive.login_with_oauth(auth.access_token)
end

def transactions_worksheet
  HotCustardApp.cache.fetch "transactions_worksheet" do
    worksheet("Transactions", google_session) 
  end
end

def all_individual_balances_worksheet
  HotCustardApp.cache.fetch "all_individual_balances_worksheet" do
    worksheet("All individual balances", google_session) 
  end
end

def individual_balances_for_logged_in_user
  row = all_individual_balances_worksheet.list.to_hash_array.select { |row| row["Person"] == logged_in_user }.first
  row.to_hash.select{|key, value| worth_showing?(value) }
end

def worth_showing? monetary_string
  int_value = monetary_string.delete("£").to_i
  (int_value >= 1) or (int_value <= -1)
end

def individual_transactions_for_logged_in_user transactions_worksheet
  transactions_worksheet.list.to_hash_array.select{|row| row["Person"] == logged_in_user}
end

def user_datastore
  Redis.new
end

def logged_in_user
  user_datastore[session[:uid]]
end

helpers do
  def number_of_payment_items_for(transaction)
    (1..13).each do |index|
      return (index -1) if transaction["Item #{index}"].strip.empty?
    end
    13
  end
end

get '/auth/facebook/callback' do
  session[:uid] = env['omniauth.auth']['uid']
  redirect to('/payments')
end

end