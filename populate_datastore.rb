require 'redis'
require 'googleauth'
require 'google/apis/sheets_v4'
require 'json'
require 'dotenv'
require 'active_support/core_ext/string/inflections'
require 'base64'
Dotenv.load
# Dotenv.load "prod.env"
require_relative 'hot_custard_payments'
require_relative 'hcmoney'

SPREADSHEET_KEY = ENV['SPREADSHEET_KEY']
DATASTORE = Redis.new(url: ENV['REDIS_URL'])
GOOGLE_APPLICATION_CREDENTIALS = Base64.decode64(ENV['ENCODED_GOOGLE_APPLICATION_CREDENTIALS'])

def transactions_worksheet
  to_hash_array(worksheet('Transactions')).reject { |row| row['Date'].blank? }
end

def store_transactions
  transactions_worksheet.each { |t| DATASTORE.rpush "transactions:#{t['Person']}", t.to_json }
end

def spreadsheet_keys
  worksheet('Spreadsheets!A2:A').flatten
end

def balances
  Hash.new({}).tap do |balances|
    spreadsheet_keys.each do |key|
      people = worksheet('PeopleWithCosts', key)[0]
      amounts = worksheet('IndividualAmounts', key)[0]
      title = title(key)
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

def title(spreadsheet_key)
  google_sheets.get_spreadsheet(spreadsheet_key).properties.title
end

def facebook_people(people)
  people.select { |person| person['Facebook name'].present? }
end

def people_worksheet
  to_hash_array(worksheet(people_worksheet_range))
end

def store_facebook_people(people)
  facebook_people(people).each do |person|
    DATASTORE.set "facebook_name:#{person['Facebook name']}", person['Name']
  end
end

def store_parameterized_people(people)
  people.each do |person|
    DATASTORE.set "parameterized_name:#{person['Name'].parameterize}", person['Name']
  end
end

def store_user_profile(people)
  DATASTORE.set 'people', people.map { |person| person['Name'] }
  store_parameterized_people people
  store_facebook_people people
  DATASTORE.sadd 'financial_admins', financial_admins(people)
  DATASTORE.sadd 'australia_payers', australia_payers(people)
end

def to_hash_array(cells_with_header_row)
  cells_with_header_row.drop(1).map do |row|
    # we need to remove leading and trailing whitespace from all cells or there will be subtle bugs
    stripped = row.map(&:strip)
    cells_with_header_row[0].zip(stripped).to_h
  end
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

def worksheet(range, spreadsheet_key = SPREADSHEET_KEY, value_render_option: nil)
  google_sheets.get_spreadsheet_values(
    spreadsheet_key, range, value_render_option: value_render_option
  ).values
end

def flush_datastore
  DATASTORE.flushdb
end

def google_sheets
  Google::Apis::SheetsV4::SheetsService.new.tap do |service|
    service.authorization = decoded_google_authorization_from_env
  end
end

def decoded_google_authorization_from_env
  Google::Auth::ServiceAccountCredentials.make_creds(
    scope: 'https://www.googleapis.com/auth/spreadsheets',
    json_key_io: StringIO.new(GOOGLE_APPLICATION_CREDENTIALS)
  )
end

flush_datastore
DATASTORE.pipelined do
  store_user_profile people_worksheet
  store_transactions
  store_individual_balances_and_creditors
end
