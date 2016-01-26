require 'capybara/rspec'
require 'omniauth'
require 'dotenv'
require_relative '../hot_custard_payments'

Dotenv.load

VALID_USER_FACEBOOK_NAME = ENV['VALID_USER_FACEBOOK_NAME']
VALID_USER_NAME = ENV['VALID_USER_NAME']

def app
  Rack::Builder.parse_file('config.ru').first
end

def invalid_facebook_id
 "123456"
end

Capybara.app = app

feature "Full journey tests" do

before(:all) do
  OmniAuth.config.test_mode = true
end

before(:each) do
  OmniAuth.config.mock_auth[:facebook] = nil
end

scenario "user_with_facebook_id_in_database_should_see_transactions_and_payments_due" do
  OmniAuth.config.add_mock(:facebook, {info: {name: VALID_USER_FACEBOOK_NAME}})
  visit '/'
  expect(page).to have_content "#{VALID_USER_NAME} HC payments due"
end

scenario "user_without_facebook_id_in_database_should_see_error_message" do
  OmniAuth.config.add_mock(:facebook, {:uid => invalid_facebook_id})
  visit '/'
  expect(page).to have_content "Sorry, we haven't activated this feature for you yet."
  expect(page).to have_content "If you are a Hot Custard member then we'll endeavour to activate it as soon as we can for you :-)"
end

scenario "user who enters invalid facebook username or password should be returned to login screen" do
  OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
  visit '/'
  expect(page).to have_content "Authentication failure"
end

# scenario "root url should redirect to /payments" do

# end

# scenario "unassociated page is not hidden behind authentication" do

# end

end
