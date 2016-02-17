require 'monetize'
require 'money'

class HCMoney

  def self.amount_that_can_be_credited(creditor_balance:, hot_custard_balance:)
    return [hot_custard_balance, -creditor_balance].max if hot_custard_balance.negative?
    case hot_custard_balance <=> creditor_balance
      when -1 then hot_custard_balance
      when 0 then hot_custard_balance
      when 1 then creditor_balance
    end
  end

  attr_reader :money

  def initialize monetary_string
    @monetary_string = monetary_string
    @money = Monetize.parse(monetary_string, "GBP")
  end

  def to_s
    @money.format(symbol: true, sign_before_symbol: true)
  end

  def to_i
    @money.to_i
  end

  def worth_showing?
    return false if blank? @monetary_string
    (to_i >= 1) or (to_i <= -1)
  end

  def blank? string
    string.nil? || string.strip.empty?
  end

  def -(other_hc_money)
    HCMoney.new((@money - other_hc_money.money).to_s)
  end

  # returns a new instance with changed polarity
  def -@
    HCMoney.new((- @money).to_s)
  end

  def +(other_hc_money)
    HCMoney.new((@money + other_hc_money.money).to_s)
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
