require 'redis'
require 'googleauth'
require 'google/apis/sheets_v4'
require 'json'
require 'dotenv'
require 'active_support/core_ext/string/inflections'
Dotenv.load
# Dotenv.load "prod.env"
require_relative 'hot_custard_payments'
require_relative 'hcmoney'

SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
DATASTORE = Redis.new(url: ENV["REDIS_URL"])

def store_transactions
  worksheet_transactions = to_hash_array(worksheet("Transactions")).reject{|row| row["Date"].blank?}
  worksheet_transactions.each {|t| DATASTORE.rpush "transactions:#{t["Person"]}", t.to_json }
end

def store_individual_balances_and_creditors
  balances_sheet = to_hash_array(worksheet("All individual balances"))
  balances_sheet.reject{|item| ["Person", ""].include? item["Person"]}.each do|i|
  	DATASTORE.set "balance:#{i["Person"]}", i.to_json
    DATASTORE.sadd('creditors', i["Person"]) if (HCMoney.new(i["Total"]).in_credit? and (i["Person"] != "Hot Custard"))
  end
end

def store_user_profile
  people = to_hash_array(worksheet(people_worksheet_range))
  DATASTORE.set 'people', people.map{|person| person["Name"]}
  people.each {|person| DATASTORE.set "parameterized_name:#{person["Name"].parameterize}", person["Name"]}
  facebook_people = people.select{|person| person["Facebook name"].present?}
  facebook_people.each {|person| DATASTORE.set "facebook_name:#{person["Facebook name"]}", person["Name"]}
  DATASTORE.sadd 'financial_admins', financial_admins(people)
  DATASTORE.sadd 'australia_payers', australia_payers(people)
end

def to_hash_array cells_with_header_row
  cells_with_header_row.drop(1).map { |row| cells_with_header_row[0].zip(row).to_h }
end

def financial_admins people
  people.select{|person| person["Financial admin"] == "Yes"}.map{|person| person["Name"]}
end

def australia_payers people
  people.select{|person| person["Australia payer"] == "Yes"}.map{|person| person["Name"]}
end

# need to specify the columns for this sheet, otherwise if just specifying the worksheet name it
# will collide with the named range of the same name, and the named range will be chosen
# (which is not what we want).  See http://stackoverflow.com/questions/39638240
def people_worksheet_range
  "People!A:G"
end

def worksheet range
  google_sheets.get_spreadsheet_values(SPREADSHEET_KEY, range).values
end


def flush_datastore
  DATASTORE.flushdb
end

def google_sheets
  Google::Apis::SheetsV4::SheetsService.new.tap do |sheets|
    sheets.authorization = google_authorization
  end
end

def google_authorization
  Google::Auth.get_application_default(['https://www.googleapis.com/auth/spreadsheets.readonly'])
end

flush_datastore
DATASTORE.pipelined do
  store_user_profile
  store_transactions
  store_individual_balances_and_creditors
end
