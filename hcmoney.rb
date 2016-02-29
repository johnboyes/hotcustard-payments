require 'monetize'
require 'money'
require 'money/bank/google_currency'

class HCMoney

  Money::Bank::GoogleCurrency.ttl_in_seconds = 3
  Money.default_bank = Money::Bank::GoogleCurrency.new

  def self.amount_that_can_be_credited(creditor_balance:, hot_custard_balance:)
    return [hot_custard_balance, -creditor_balance].max if hot_custard_balance.negative?
    case hot_custard_balance <=> creditor_balance
      when -1 then hot_custard_balance
      when 0 then hot_custard_balance
      when 1 then creditor_balance
    end
  end

  attr_reader :money

  def initialize monetary_string, currency = "GBP"
    @monetary_string = monetary_string
    @money = Monetize.parse(monetary_string, currency)
  end

  def to_s
    @money.format(symbol: true, sign_before_symbol: true)
  end

  def to_i
    @money.to_i
  end

  def to_australian_dollars markup_percentage = 0
    amount_from_google = HCMoney.new @money.exchange_to(:AUD).dollars.to_s('F'), "AUD"
    amount_from_google.markup_to_cover_transfer_fees_and_rate_fluctuation markup_percentage
  end

  def markup_to_cover_transfer_fees_and_rate_fluctuation markup_percentage
    self + (self * (markup_percentage.to_f / 100))
  end

  def worth_showing?
    return false if blank? @monetary_string
    (to_i >= 1) or (to_i <= -1)
  end

  def blank? string
    string.nil? || string.strip.empty?
  end

  def -(other_hc_money)
    HCMoney.new (@money - other_hc_money.money).to_s, @money.currency
  end

  # returns a new instance with changed polarity
  def -@
    HCMoney.new (- @money).to_s, @money.currency
  end

  def +(other_hc_money)
    HCMoney.new (@money + other_hc_money.money).to_s, @money.currency
  end

  def *(value)
    HCMoney.new (@money * value).to_s, @money.currency
  end

  def /(value)
    HCMoney.new (@money / value).to_s, @money.currency
  end

  def <=>(other_hc_money)
    return nil unless other_hc_money.is_a?(HCMoney)
    @money <=> other_hc_money.money
  end

  def negative?
    @money.negative?
  end

  def positive?
    @money.positive?
  end

  def in_credit?
    positive? && worth_showing?
  end

end
