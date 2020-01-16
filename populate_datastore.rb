require 'redis'
require 'googleauth'
require 'google/apis/sheets_v4'
require 'json'
require 'active_support/core_ext/string/inflections'
require 'base64'
require_relative 'google_sheet'
require_relative 'hot_custard_payments'
require_relative 'hcmoney'

SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
DATASTORE = Redis.new(url: ENV['REDIS_URL'])

def check_worksheets
  spreadsheet_keys.reverse.take(20).each_with_index { |key, i| check_worksheet(key) }
end

def check_worksheet(spreadsheet_key)
  people_with_costs = GoogleSheet.range(spreadsheet_key, 'PeopleWithCosts')
  start_row = people_with_costs[:boundaries][:start_row]
  full_people_row = GoogleSheet.range(spreadsheet_key, "#{start_row}:#{start_row}")[:values].first
  raise invalid_spreadsheet_message(spreadsheet_key) unless full_people_row_valid? full_people_row
  puts "Successfully validated spreadsheet #{spreadsheet_key}"
end

def invalid_spreadsheet_message(spreadsheet_key)
  "Spreadsheet with key: #{spreadsheet_key} is in an invalid state"
end

def full_people_row_valid?(full_people_row)
  sliced = full_people_row.slice_after('').to_a
  return false unless sliced.size == 5
  return false unless sliced[1..3].all? { |a| a == [''] }
  sliced[0].pop
  return false unless sliced[0] == sliced[4]
  return false unless sliced[0] == sliced[0].uniq
  true
end

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
      amounts = GoogleSheet.worksheet(key, 'IndividualAmounts').first
      title = GoogleSheet.title(key)
      people(key).each_with_index do |person, index|
        balances[person] = balances[person].merge(title => amounts[index])
      end
    end
  end
end

def people(spreadsheet_key)
  GoogleSheet.worksheet(spreadsheet_key, 'PeopleWithCosts').first
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
  DATASTORE.set('people', people.map { |person| person['Name'] })
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
  check_worksheets
  store_user_profiles people_worksheet
  store_transactions
  store_individual_balances_and_creditors
end
