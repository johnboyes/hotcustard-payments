require 'redis'
require 'googleauth'
require 'google/apis/sheets_v4'
require 'json'
require 'dotenv'
require 'active_support/core_ext/string/inflections'
require 'base64'
Dotenv.load
# Dotenv.load 'prod.env'
require_relative 'google_sheet'
require_relative 'hot_custard_payments'
require_relative 'hcmoney'

SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
DATASTORE = Redis.new(url: ENV['REDIS_URL'])

def transactions_worksheet
  GoogleSheet.worksheet(SPREADSHEET_KEY, 'Transactions', hash_array: true).reject do |row|
    row['Date'].blank?
  end
end

def store_transactions
  transactions_worksheet.each { |t| DATASTORE.rpush "transactions:#{t['Person']}", t.to_json }
end

def spreadsheet_keys
  GoogleSheet.worksheet(SPREADSHEET_KEY, 'Spreadsheets!A2:A').flatten
end

def balances
  Hash.new({}).tap do |balances|
    spreadsheet_keys.each do |key|
      people = GoogleSheet.worksheet(key, 'PeopleWithCosts')[0]
      amounts = GoogleSheet.worksheet(key, 'IndividualAmounts')[0]
      title = GoogleSheet.title(key)
      people.each_with_index do |person, index|
        balances[person] = balances[person].merge(title => amounts[index])
      end
    end
  end
end

def store_individual_balances_and_creditors
  balances.each do |person, balance|
    DATASTORE.set "balance:#{person}", balance.to_json
    total = balance.values.map { |amount| HCMoney.new(amount) }.inject(:+)
    DATASTORE.sadd('creditors', person) if total.in_credit? && (person != 'Hot Custard')
  end
end

def people_worksheet
  GoogleSheet.worksheet(SPREADSHEET_KEY, people_worksheet_range, hash_array: true)
end

def store_facebook_people(people)
  facebook_people(people).each do |person|
    DATASTORE.set "facebook_name:#{person['Facebook name']}", person['Name']
  end
end

def facebook_people(people)
  people.select { |person| person['Facebook name'].present? }
end

def store_parameterized_people(people)
  people.each do |person|
    DATASTORE.set "parameterized_name:#{person['Name'].parameterize}", person['Name']
  end
end

def store_user_profiles(people)
  DATASTORE.set 'people', people.map { |person| person['Name'] }
  store_parameterized_people people
  store_facebook_people people
  DATASTORE.sadd 'financial_admins', financial_admins(people)
  DATASTORE.sadd 'australia_payers', australia_payers(people)
end

def financial_admins(people)
  people.select { |person| person['Financial admin'] == 'Yes' }.map { |person| person['Name'] }
end

def australia_payers(people)
  people.select { |person| person['Australia payer'] == 'Yes' }.map { |person| person['Name'] }
end

# need to specify the columns for this sheet, otherwise if just specifying the worksheet name it
# will collide with the named range of the same name, and the named range will be chosen
# (which is not what we want).  See http://stackoverflow.com/questions/39638240
def people_worksheet_range
  'People!A:G'
end

def flush_datastore
  DATASTORE.flushdb
end

flush_datastore
DATASTORE.pipelined do
  store_user_profiles people_worksheet
  store_transactions
  store_individual_balances_and_creditors
end
