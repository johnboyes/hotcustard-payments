require 'capybara/rspec'
require 'omniauth'
require 'dotenv'
require_relative '../hot_custard_payments'

Dotenv.load

VALID_USER_FACEBOOK_ID = ENV['VALID_USER_FACEBOOK_ID']
VALID_USER_NAME = ENV['VALID_USER_NAME']

def app
  Rack::Builder.parse_file('config.ru').first
end

Capybara.app = app

feature "Full journey tests" do

before(:each) do
  OmniAuth.config.test_mode = true
end

scenario "user_with_facebook_id_in_database_should_see_transactions_and_payments_due" do
  OmniAuth.config.add_mock(:facebook, {:uid => VALID_USER_FACEBOOK_ID})
  visit '/'
  expect(page).to have_content "#{VALID_USER_NAME} HC payments due"
end

# scenario "user_without_facebook_id_in_database_should_see_error_message" do
#   # what error message to display
# end

scenario "user who enters invalid facebook username or password should be returned to login screen" do
  OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
  visit '/'
  expect(page).to have_content "Authentication failure"
end

# scenario "root url should redirect to /payments" do

# end

end