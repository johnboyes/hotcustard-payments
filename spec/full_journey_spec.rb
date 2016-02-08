require 'capybara/rspec'
require 'omniauth'
require 'dotenv'
require 'monetize'
require_relative '../hot_custard_payments'

Dotenv.load

REGULAR_USER_FACEBOOK_NAME = ENV['REGULAR_USER_FACEBOOK_NAME']
REGULAR_USER_NAME = ENV['REGULAR_USER_NAME']
FINANCIAL_ADMIN_FACEBOOK_NAME = ENV['FINANCIAL_ADMIN_FACEBOOK_NAME']
FINANCIAL_ADMIN_USER_NAME = ENV['FINANCIAL_ADMIN_USER_NAME']
CREDITOR_NAME = ENV['CREDITOR_NAME']

def app
  Rack::Builder.parse_file('config.ru').first
end

def unactivated_facebook_name
 "Joe Unactivated"
end

Capybara.app = app

feature "Full journey tests" do

before(:all) do
  OmniAuth.config.test_mode = true
end

before(:each) do
  OmniAuth.config.mock_auth[:facebook] = nil
end

scenario "regular user_with_facebook_id_in_database_should_see_transactions_and_payments_due" do
  login REGULAR_USER_FACEBOOK_NAME
  visit '/'
  expect(REGULAR_USER_NAME).not_to be_empty
  expect(page).to have_content "#{REGULAR_USER_NAME} HC payments due"
  expect(page).to have_content "#{REGULAR_USER_NAME} HC bank transactions"
  expect_all_amounts_to_be_monetary
  expect_all_dates_to_be_valid
  expect(page).to have_current_path("/payments")
end

scenario "user_without_facebook_name_in_datastore_should_see_error_message" do
  login "Joe Notindatastore"
  visit '/'
  expect_unactivated_page_content
end

scenario "user who enters invalid facebook username or password should be returned to login screen" do
  OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
  visit '/'
  expect(page).to have_content "Authentication failure"
end

scenario "unassociated page is not hidden behind authentication" do
  visit '/auth/unassociated'
  expect_unactivated_page_content
end

scenario "financial admins can see everyone's balances and transactions" do
  login FINANCIAL_ADMIN_FACEBOOK_NAME
end

scenario "regular users can only see their own balances and transactions" do
  login REGULAR_USER_FACEBOOK_NAME
end

scenario "financial admins can see what anyone who is owed money can be paid back" do
 # show a breakdown of what the person is owed, and whether Custard have had enough payments to pay the person back
  login FINANCIAL_ADMIN_FACEBOOK_NAME
  visit '/'
  visit '/payments/creditors'
  expect(page.status_code).to be 200
  expect(page).to have_content "HC money that can be paid to #{CREDITOR_NAME}"
  expect_all_amounts_to_be_monetary
end

scenario "regular users cannot see what anyone who is owed money can be paid back" do
  login REGULAR_USER_FACEBOOK_NAME
  visit '/'
  visit '/payments/creditors'
  expect(page.status_code).to be 403
end

def login facebook_name
  OmniAuth.config.add_mock(:facebook, {info: {name: facebook_name}})
end

def expect_unactivated_page_content
  expect(page.status_code).to be 403
  expect(page).to have_content "Sorry, we haven't activated this feature for you yet."
  expect(page).to have_content "If you are a Hot Custard member then we'll endeavour to activate it as soon as we can for you :-)"
end

def expect_all_amounts_to_be_monetary
  all_amounts = page.all(:css, '.amount')
  expect(all_amounts).not_to be_empty
  all_amounts.each {|amount| expect_monetary_amount(amount.text)}
end

def expect_monetary_amount value
  Monetize.assume_from_symbol = true
  expect(value).to eq Monetize.parse(value).format(sign_before_symbol: true)
end

def expect_all_dates_to_be_valid
  all_dates = page.all(:css, '.date')
  expect(all_dates).not_to be_empty
  all_dates.each{|date| expect_date_in_correct_format(date.text)}
end

def expect_date_in_correct_format date
  expect(date).to eq Date.strptime(date, '%e %b %y').strftime('%e %b %y').strip
end

end
