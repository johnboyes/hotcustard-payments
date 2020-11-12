require 'monetize'
require 'money'
require 'money_oxr/bank'

# see https://github.com/RubyMoney/money/issues/593
I18n.enforce_available_locales = false

# Hot Custard tailored implementation of money
class HCMoney
  Money.locale_backend = :i18n
  Money.default_bank = MoneyOXR::Bank.new(
    app_id: ENV['OPEN_EXCHANGE_RATES_APP_ID'],
    cache_path: '/tmp/oxr.json',
    max_age: 86_400
  )

  MoneyOXR::RatesStore.new(
    app_id: ENV['OPEN_EXCHANGE_RATES_APP_ID'],
    cache_path: '/tmp/oxr.json',
    max_age: 86_400
  ).load

  def self.amount_that_can_be_credited(creditor_balance:, hot_custard_balance:)
    return [hot_custard_balance, -creditor_balance].max if hot_custard_balance.negative?

    case hot_custard_balance <=> creditor_balance
    when -1,0 then hot_custard_balance
    when 1 then creditor_balance
    end
  end

  def self.zero
    new(0)
  end

  attr_reader :money

  def initialize(monetary_string, currency = 'GBP')
    @monetary_string = monetary_string
    @money = Monetize.parse(monetary_string, currency)
  end

  def to_s
    @money.format(symbol: true, sign_before_symbol: true)
  end

  def to_i
    @money.to_i
  end

  def to_australian_dollars(markup_percentage = 0)
    amount_from_google = HCMoney.new(@money.exchange_to(:AUD).dollars.to_s('F'), 'AUD')
    amount_from_google.markup_to_cover_transfer_fees_and_rate_fluctuation markup_percentage
  end

  def markup_to_cover_transfer_fees_and_rate_fluctuation(markup_percentage)
    self + (self * (markup_percentage.to_f / 100))
  end

  def worth_showing?
    return false if blank? @monetary_string

    (to_i >= 1) || (to_i <= -1)
  end

  def blank?(string)
    string.nil? || string.strip.empty?
  end

  def -(other)
    HCMoney.new (@money - other.money).to_s, @money.currency
  end

  # returns a new instance with changed polarity
  def -@
    HCMoney.new (- @money).to_s, @money.currency
  end

  def +(other)
    HCMoney.new (@money + other.money).to_s, @money.currency
  end

  def *(other)
    HCMoney.new (@money * other).to_s, @money.currency
  end

  def /(other)
    HCMoney.new (@money / other).to_s, @money.currency
  end

  def <=>(other)
    return nil unless other.is_a?(HCMoney)

    @money <=> other.money
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
