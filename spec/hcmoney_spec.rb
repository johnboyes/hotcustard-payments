require 'rspec'
require_relative '../hcmoney'

describe HCMoney, ".amount_that_can_be_credited" do

  it "is same as Hot Custard balance when Hot Custard balance is smaller than creditor balance" do
    @hot_custard_balance = "5"
    @creditor_balance = "10"
    expect(amount_that_can_be_credited).to eq "£5.00"
  end
  it "is same as creditor balance when Hot Custard balance is greater than creditor balance" do
    @hot_custard_balance = "20"
    @creditor_balance = "15"
    expect(amount_that_can_be_credited).to eq "£15.00"
  end

  it "is same as creditor balance when Hot Custard balance is same as creditor balance" do
    @hot_custard_balance = "5"
    @creditor_balance = "5"
    expect(amount_that_can_be_credited).to eq "£5.00"
  end

  it "is zero when Hot Custard balance is zero" do
    @hot_custard_balance = "0"
    @creditor_balance = "5"
    expect(amount_that_can_be_credited).to eq "£0.00"
  end

  it "is zero when creditor balance is zero" do
    @hot_custard_balance = "5"
    @creditor_balance = "0"
    expect(amount_that_can_be_credited).to eq "£0.00"
  end

  it "is is whichever amount is closer to zero when hot custard balance is negative" do
    @hot_custard_balance = "-1"
    @creditor_balance = "5"
    expect(amount_that_can_be_credited).to eq "-£1.00"
  end

  it "is is whichever amount is closer to zero when creditor balance is negative" do
    @hot_custard_balance = "10"
    @creditor_balance = "-1"
    expect(amount_that_can_be_credited).to eq "-£1.00"
  end

  def amount_that_can_be_credited
    HCMoney.amount_that_can_be_credited(
      hot_custard_balance: HCMoney.new(@hot_custard_balance),
      creditor_balance: HCMoney.new(@creditor_balance)).to_s
  end

end


describe HCMoney, "#worth_showing?" do

  ["£0.99", "-£0.99"].each do |value|
    it "is not worth showing when #{value}" do
      expect(HCMoney.new(value ).worth_showing?).to be false
    end
  end

  ["£1", "-£1"].each do |value|
    it "is worth showing when #{value}" do
      expect(HCMoney.new(value ).worth_showing?).to be true
    end
  end

end


describe HCMoney, "#in_credit?" do

  ["£0.99", "-£0.01", "£0"].each do |value|
    it "is not in credit when #{value}" do
      expect(HCMoney.new(value).in_credit?).to be false
    end
  end

  it "is in credit when £1" do
    expect(HCMoney.new("£1").in_credit?).to be true
  end

end
