require 'capybara/rspec'
require 'omniauth'
require 'dotenv'
require 'monetize'
require 'active_support'
require 'rspec/expectations'
require_relative '../hot_custard_payments'

Dotenv.load

REGULAR_USER_FACEBOOK_NAME = ENV['REGULAR_USER_FACEBOOK_NAME']
REGULAR_USER_NAME = ENV['REGULAR_USER_NAME']
DEBT_FREE_USER_FACEBOOK_NAME = ENV['DEBT_FREE_USER_FACEBOOK_NAME']
DEBT_FREE_USER_NAME = ENV['DEBT_FREE_USER_NAME']
NO_TRANSACTIONS_USER_FACEBOOK_NAME = ENV['NO_TRANSACTIONS_USER_FACEBOOK_NAME']
NO_TRANSACTIONS_USER_NAME = ENV['NO_TRANSACTIONS_USER_NAME']
FINANCIAL_ADMIN_FACEBOOK_NAME = ENV['FINANCIAL_ADMIN_FACEBOOK_NAME']
FINANCIAL_ADMIN_USER_NAME = ENV['FINANCIAL_ADMIN_USER_NAME']
CREDITOR_NAME = ENV['CREDITOR_NAME']
UK_ACCOUNT_NAME = ENV['UK_ACCOUNT_NAME']
UK_SORT_CODE = ENV['UK_SORT_CODE']
UK_ACCOUNT_NUMBER = ENV['UK_ACCOUNT_NUMBER']
AUS_PAYER_FACEBOOK_NAME = ENV['AUS_PAYER_FACEBOOK_NAME']
AUS_ACCOUNT_NAME = ENV['AUS_ACCOUNT_NAME']
AUS_BSB = ENV['AUS_BSB']
AUS_ACCOUNT_NUMBER = ENV['AUS_ACCOUNT_NUMBER']

def app
  Rack::Builder.parse_file('config.ru').first
end

def unactivated_facebook_name
  'Joe Unactivated'
end

Capybara.app = app

feature 'Full journey tests' do
  before(:all) { OmniAuth.config.test_mode = true }

  before(:each) { OmniAuth.config.mock_auth[:facebook] = nil }

  scenario 'regular user with facebook id in database should see transactions and payments due' do
    login REGULAR_USER_FACEBOOK_NAME
    visit '/'
    expect(REGULAR_USER_NAME).not_to be_empty
    expect(page).to have_content "#{REGULAR_USER_NAME} HC payments due"
    expect(page).to have_content "#{REGULAR_USER_NAME} HC bank transactions"
    expect_all_amounts_to_be_monetary
    expect(HCMoney.new(total_balance).negative?).to be
    expect(page).not_to have_content debt_free_message
    expect(page).not_to have_content no_transactions_message
    expect_all_dates_to_be_valid
    expect(page).to have_current_path('/payments')
  end

  scenario 'regular user should see UK HC bank account details only' do
    login REGULAR_USER_FACEBOOK_NAME
    visit '/'
    expect_uk_bank_details
    expect(page).not_to have_content australia_bank_message
    expect(page).not_to have_content '$'
  end

  scenario 'australia payer should see UK and Aus HC bank account details' do
    login AUS_PAYER_FACEBOOK_NAME
    visit '/'
    expect(page).to have_content australia_bank_message
    expect(page).to have_content "Account name: #{AUS_ACCOUNT_NAME}"
    expect(page).to have_content "BSB: #{AUS_BSB}"
    expect(page).to have_content "Account number: #{AUS_ACCOUNT_NUMBER}"
    expect_uk_bank_details
  end

  scenario 'australia payer should see total balance in pounds and australian dollars' do
    login AUS_PAYER_FACEBOOK_NAME
    visit '/'
    expect(total_balance).to be_an_amount_in '£'
    expect(total_balance_in_australian_dollars).to be_an_amount_in '$'
  end

  scenario 'debt free user should see a total of zero owing and a congratulatory message' do
    login DEBT_FREE_USER_FACEBOOK_NAME
    visit '/'
    expect(DEBT_FREE_USER_NAME).not_to be_empty
    expect(page).to have_content "#{DEBT_FREE_USER_NAME} HC payments due"
    expect(page).to have_content "#{DEBT_FREE_USER_NAME} HC bank transactions"
    expect(total_balance).to eq '£0.00'
    expect(page).to have_content debt_free_message
    expect_all_amounts_to_be_monetary
    expect_all_dates_to_be_valid
    expect(page).to have_current_path('/payments')
  end

  scenario 'user with no transactions yet should see a message saying so' do
    login NO_TRANSACTIONS_USER_FACEBOOK_NAME
    visit '/'
    expect(DEBT_FREE_USER_NAME).not_to be_empty
    expect(page).to have_content "#{NO_TRANSACTIONS_USER_NAME} HC payments due"
    expect(page).to have_content "#{NO_TRANSACTIONS_USER_NAME} HC bank transactions"
    expect(page).to have_content no_transactions_message
    expect(all_dates).to be_empty
    expect_all_amounts_to_be_monetary
    expect(page).to have_current_path('/payments')
  end

  scenario 'user without facebook name in datastore should see error message' do
    login 'Joe Notindatastore'
    visit '/'
    expect_unactivated_page_content
  end

  scenario 'user who enters invalid facebook username or password is returned to login screen' do
    OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
    visit '/'
    expect(page).to have_content 'Authentication failure'
  end

  scenario 'unassociated page is not hidden behind authentication' do
    visit '/auth/unassociated'
    expect_unactivated_page_content
  end

  scenario "financial admins can see everyone's balances and transactions" do
    login FINANCIAL_ADMIN_FACEBOOK_NAME
    visit '/'
    page.select REGULAR_USER_NAME, from: 'person'
    click_on 'Submit'
    expect(page.current_path).to eq "/payments/#{REGULAR_USER_NAME.parameterize}"
    expect(page.status_code).to be 200
    expect(REGULAR_USER_NAME).not_to be_empty
    expect(page).to have_content "#{REGULAR_USER_NAME} HC payments due"
    expect(page).to have_content "#{REGULAR_USER_NAME} HC bank transactions"
    expect_all_amounts_to_be_monetary
    expect_all_dates_to_be_valid
  end

  scenario "financial admins can navigate to people's payments" do
    login FINANCIAL_ADMIN_FACEBOOK_NAME
    visit '/'
    page.select REGULAR_USER_NAME, from: 'person'
    click_on 'Submit'
    page.select FINANCIAL_ADMIN_USER_NAME, from: 'person'
    click_on 'Submit'
    expect(page.current_path).to eq "/payments/#{FINANCIAL_ADMIN_USER_NAME.parameterize}"
    expect(FINANCIAL_ADMIN_USER_NAME).not_to be_empty
    expect(page).to have_content "#{FINANCIAL_ADMIN_USER_NAME} HC payments due"
  end

  scenario 'regular users can only see their own balances and transactions' do
    login REGULAR_USER_FACEBOOK_NAME
    visit '/'
    expect(page).not_to have_button 'Submit'
    visit "/payments/#{REGULAR_USER_NAME.parameterize}"
    expect(page.status_code).to be 403
  end

  scenario 'financial admins can see what anyone who is owed money can be paid back' do
    login FINANCIAL_ADMIN_FACEBOOK_NAME
    visit '/'
    click_on 'Creditors'
    expect(page.current_path).to eq '/payments/creditors'
    expect(page.status_code).to be 200
    expect(page).to have_content "HC money that can be paid to #{CREDITOR_NAME}"
    expect_all_amounts_to_be_monetary
  end

  scenario 'regular users cannot see what anyone who is owed money can be paid back' do
    login REGULAR_USER_FACEBOOK_NAME
    visit '/'
    expect(page).not_to have_content 'Creditors'
    visit '/payments/creditors'
    expect(page.status_code).to be 403
  end

  scenario 'financial admins can see a list of debtors' do
    login FINANCIAL_ADMIN_FACEBOOK_NAME
    visit '/'
    click_on 'Debtors'
    expect(page.current_path).to eq '/payments/debtors'
    expect(page.status_code).to be 200
    expect(page).to have_content 'Hot Custard Current Debtors'
    expect_all_amounts_to_be_monetary
  end

  scenario 'regular users cannot see a list of debtors' do
    login REGULAR_USER_FACEBOOK_NAME
    visit '/'
    expect(page).not_to have_content 'Debtors'
    visit '/payments/debtors'
    expect(page.status_code).to be 403
  end

  scenario 'privacy policy' do
    visit '/privacy'
    expect(page).to have_content 'Privacy Policy'
  end

  def expect_uk_bank_details
    [
      'UK HC bank details',
      "Account name: #{UK_ACCOUNT_NAME}",
      "Sort code: #{UK_SORT_CODE}",
      "Account number: #{UK_ACCOUNT_NUMBER}"
    ].each { |content| expect(page).to have_content content }
  end

  RSpec::Matchers.define :be_an_amount_in do |symbol|
    match do |amount|
      amount.include? symbol
      expect_monetary_amount amount
    end
  end

  def australia_bank_message
    'Australia HC bank details'
  end

  def no_transactions_message
    'No HC bank transactions yet'
  end

  def debt_free_message
    'There is nothing to pay, well done!'
  end

  def total_balance
    page.find('#total-balance').text
  end

  def total_balance_in_australian_dollars
    page.find('#total-balance-australian-dollars').text
  end

  def login(facebook_name)
    OmniAuth.config.add_mock(:facebook, info: { name: facebook_name })
  end

  def expect_unactivated_page_content
    expect(page.status_code).to be 403
    expect(page).to have_content(
      'If you are not a Hot Custard member then you are not authorised to view this application.'
    )
    expect(page).to have_content(
      'If you are a Hot Custard member then we will activate your access as soon as we can :-)'
    )
  end

  def expect_all_amounts_to_be_monetary
    all_amounts = page.all(:css, '.amount')
    expect(all_amounts).not_to be_empty
    all_amounts.each { |amount| expect_monetary_amount(amount.text) }
  end

  def expect_monetary_amount(value)
    Monetize.assume_from_symbol = true
    expect(value).to eq Monetize.parse(value).format(sign_before_symbol: true)
  end

  def expect_all_dates_to_be_valid
    expect(all_dates).not_to be_empty
    all_dates.each { |date| expect_date_in_correct_format(date.text) }
  end

  def all_dates
    page.all(:css, '.date')
  end

  def expect_date_in_correct_format(date)
    expect(date).to eq Date.strptime(date, '%e %b %y').strftime('%e %b %y').strip
  end
end
