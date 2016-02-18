require 'redis'
require 'google/api_client'
require 'google_drive'
require 'json'
require 'dotenv'
require 'active_support/core_ext/string/inflections'
Dotenv.load
# Dotenv.load "prod.env"
require_relative 'hot_custard_payments'
require_relative 'hcmoney'

GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS = ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL_ADDRESS']
PRIVATE_KEY = ENV['PRIVATE_KEY']
SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
GOOGLE_API_VERSION = 'v2'
DATASTORE = Redis.new(url: ENV["REDIS_URL"])

def store_transactions
  worksheet_transactions = worksheet("Transactions").list.to_hash_array.reject{|row| row["Date"].empty?}
  worksheet_transactions.each {|t| DATASTORE.rpush "transactions:#{t["Person"]}", t.to_json }
end

def store_individual_balances_and_creditors
  balances_sheet = worksheet("All individual balances").list.to_hash_array
  balances_sheet.reject{|item| ["Hot Custard", "Person", ""].include? item["Person"]}.each do|i|
  	DATASTORE.set "balance:#{i["Person"]}", i.to_json
    DATASTORE.sadd('creditors', i["Person"]) if HCMoney.new(i["Total"]).in_credit?
  end
end

def store_user_profile
  people = worksheet("People").list.to_hash_array
  DATASTORE.set 'people', people.map{|person| person["Name"]}
  people.each {|person| DATASTORE.set "parameterized_name:#{person["Name"].parameterize}", person["Name"]}
  facebook_people = people.reject{|person| person["Facebook name"].empty?}
  facebook_people.each {|person| DATASTORE.set "facebook_name:#{person["Facebook name"]}", person["Name"]}
  DATASTORE.sadd 'financial_admins', financial_admins(people)
end

def financial_admins people
  people.select{|person| person["Financial admin"] == "Yes"}.map{|person| person["Name"]}
end

def worksheet name
  google_session.spreadsheet_by_key(SPREADSHEET_KEY).worksheet_by_title name
end

def flush_datastore
  DATASTORE.flushdb
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

flush_datastore
DATASTORE.pipelined do
  store_user_profile
  store_transactions
  store_individual_balances_and_creditors
end
