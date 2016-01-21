require 'sinatra/base'
require "sinatra/cookies"
require 'koala'
require 'redis'
require 'json'
require 'pry'

class HotCustardApp < Sinatra::Base

$stdout.sync = true #so we can see stdout when starting with foreman, see https://github.com/ddollar/foreman/wiki/Missing-Output

FACEBOOK_APP_ID = ENV['FACEBOOK_APP_ID']
FACEBOOK_APP_SECRET = ENV['FACEBOOK_APP_SECRET']
FACEBOOK_CALLBACK_URL = nil
USER_DATASTORE = Redis.new(url: ENV["REDIS_URL"])

helpers do
  def current_user
    !session[:facebook_id].nil?
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  redirect to('/auth/facebook') unless current_user
end

get '/payments' do
  @person = username
  @transactions = individual_transactions_for_logged_in_user
  @balance = individual_balances_for_logged_in_user
  erb :transactions
end

def individual_balances_for_logged_in_user
  JSON.parse(user_datastore["balance:#{username}"]).select{|key, value| worth_showing?(value) }
end

def blank? string
  string.nil? || string.empty?
end

def worth_showing? monetary_string
  return false if blank? monetary_string
  int_value = monetary_string.delete("£").to_i
  (int_value >= 1) or (int_value <= -1)
end

def individual_transactions_for_logged_in_user
  user_datastore.lrange("transactions:#{username}", 0, -1).map { |t| JSON.parse(t)}
end

def user_datastore
  USER_DATASTORE
end

def username
  user_datastore["facebook_id:#{session[:facebook_id]}"]
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
  session[:facebook_id] = env['omniauth.auth']['uid']
  redirect to('/payments')
end

end