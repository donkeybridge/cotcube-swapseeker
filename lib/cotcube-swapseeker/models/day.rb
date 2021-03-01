module Cotcube
  module SwapSeeker
    class Day

      attr_reader :date

      include Mongoid::Document
      has_many  :swaps, class_name: 'Swap', inverse_of: :day

      field :d, as: :date, type: Date
      validates_presence_of :d
      validates_uniqueness_of :d
      validate :date_is_a_trading_day

      def date_is_a_trading_day
        errors.add(:date, "Date must be a trading day, i.e. #{self.d.strftime('%a, %Y-%m-%d')}") if [0,6].include?(self.d.wday) or Cotcube::Bardata.holidays.include?(self.d)
      end

    end
    Days = Day
  end
end
