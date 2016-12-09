require 'sinatra/base'

# Extending the main Sinatra module
module Sinatra
  # Sinatra helper class
  module HCMoneyHelper
    def current_user
      !session[:facebook_name].nil?
    end

    def might_pay_in_aus?(person)
      australia_payers.include? person
    end

    def number_of_payment_items_for(transaction)
      (1..21).each do |index|
        return (index - 1) if transaction["Item #{index}"].blank?
      end
      21
    end

    def financial_admin?
      financial_admins.include? username
    end

    def to_australian_dollars(pounds)
      HCMoney.new(pounds).to_australian_dollars ENV['AUS_MARKUP_PERCENTAGE']
    end

    def total_credit(credits)
      credits.values.map { |amounts| amounts[:credit_amount] }.reduce(:+)
    end
  end

  helpers HCMoneyHelper
end
