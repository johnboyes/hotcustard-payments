require 'sinatra/base'
require "sinatra/cookies"
require 'koala'
require 'redis'
require 'json'
require 'omniauth'
require 'omniauth-facebook'
require 'pry'

class HotCustardApp < Sinatra::Base

$stdout.sync = true #so we can see stdout when starting with foreman, see https://github.com/ddollar/foreman/wiki/Missing-Output

USER_DATASTORE = Redis.new(url: ENV["REDIS_URL"])

helpers do
  def current_user
    !session[:facebook_name].nil?
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  redirect to('/auth/facebook') unless current_user
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
  user_datastore["facebook_name:#{session[:facebook_name]}"]
end

helpers do
  def number_of_payment_items_for(transaction)
    (1..13).each do |index|
      return (index -1) if transaction["Item #{index}"].strip.empty?
    end
    13
  end
end

get '/payments' do
  @person = username
  @transactions = individual_transactions_for_logged_in_user
  @balance = individual_balances_for_logged_in_user
  erb :payments
end

get '/auth/unassociated' do
  "Sorry, we haven't activated this feature for you yet. If you are a Hot Custard member then we'll endeavour to activate it as soon as we can for you :-)"
end

get '/auth/:provider/callback' do
  session[:facebook_name] = env['omniauth.auth']['info']['name']
  session[:username] = username
  puts env['omniauth.auth']
  redirect to '/auth/unassociated' if blank? session[:username]
  redirect to('/payments')
end

get '/auth/failure' do 
  "Authentication failure"
end

end
