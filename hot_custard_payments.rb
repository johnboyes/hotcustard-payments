require 'sinatra/base'
require "sinatra/cookies"
require 'koala'
require 'redis'
require 'json'
require 'omniauth'
require 'omniauth-facebook'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require_relative 'hcmoney'

class HotCustardApp < Sinatra::Base

$stdout.sync = true #so we can see stdout when starting with foreman, see https://github.com/ddollar/foreman/wiki/Missing-Output

USER_DATASTORE = Redis.new(url: ENV["REDIS_URL"])

helpers do
  def current_user
    !session[:facebook_name].nil?
  end

  def is_financial_admin?
    financial_admins.include? username
  end

  def number_of_payment_items_for(transaction)
    (1..13).each do |index|
      return (index -1) if transaction["Item #{index}"].blank?
    end
    13
  end

  def total_credit credits
    credits.map {|item, amounts| amounts[:credit_amount]}.reduce(:+)
  end
end

set(:role) { |role| condition { halt 403 if ((role == :financial_admin) && !is_financial_admin?) } }

before do
  pass if request.path_info =~ /^\/auth\//
  redirect to('/auth/facebook') unless current_user
end

def individual_balances_for username
  JSON.parse(user_datastore["balance:#{username}"]).select{|key, value| HCMoney.new(value).worth_showing? }
end

def individual_transactions_for username
  user_datastore.lrange("transactions:#{username}", 0, -1).map { |t| JSON.parse(t)}
end

def user_datastore
  USER_DATASTORE
end

def username
  user_datastore["facebook_name:#{session[:facebook_name]}"]
end

def financial_admins
  user_datastore.smembers "financial_admins"
end

def all_balances
  user_datastore.scan_each(:match => "balance:")
end

def creditors
  user_datastore.smembers "creditors"
end

def people
  JSON.parse user_datastore["people"]
end

def reject_total hash
  hash.reject{|key, value| key == "Total"}
end

def creditor_item_amounts creditor_balance, hot_custard_balance
  {
    creditor_balance: creditor_balance,
    hot_custard_balance: hot_custard_balance,
    credit_amount: HCMoney.amount_that_can_be_credited(creditor_balance: creditor_balance, hot_custard_balance: hot_custard_balance)
  }
end

def balances_for person
  string_balances = JSON.parse user_datastore["balance:#{person}"]
  string_balances.map { |item, amount| [item, HCMoney.new(amount)] }.to_h
end

def credits_for creditor
  creditor_balances =  reject_total(balances_for creditor).select{|item, amount| amount.in_credit?}
  hot_custard_balances = reject_total(balances_for "Hot Custard")
  Hash[creditor_balances.keys.map {|item| [item, creditor_item_amounts(creditor_balances[item], (- hot_custard_balances[item]))]}]
end

get '/payments' do
  @person = username
  @transactions = individual_transactions_for @person
  @balance = individual_balances_for @person
  @people = people
  erb :payments_with_navigation_links
end

get '/payments/creditors', role: :financial_admin do
  @creditors = Hash[creditors.map {|creditor| [creditor, credits_for(creditor)]}]
  erb :creditors
end

get '/payments/:name', role: :financial_admin do
  @person = user_datastore["parameterized_name:#{params['name']}"]
  @transactions = individual_transactions_for @person
  @balance = individual_balances_for @person
  erb :payments
end

post '/payments/person' do
  redirect to "/payments/#{params['person'].parameterize}"
end

get '/auth/unassociated' do
  status 403
  "Sorry, we haven't activated this feature for you yet. If you are a Hot Custard member then we'll endeavour to activate it as soon as we can for you :-)"
end

get '/auth/:provider/callback' do
  session[:facebook_name] = env['omniauth.auth']['info']['name']
  session[:username] = username
  puts env['omniauth.auth']
  redirect to '/auth/unassociated' if session[:username].nil? or session[:username].strip.empty?
  redirect to env['omniauth.origin'] || '/payments'
end

get '/auth/failure' do
  "Authentication failure"
end

end
