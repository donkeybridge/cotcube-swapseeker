module Cotcube
  module SwapSeeker
    class Day

      attr_reader :date

      include Mongoid::Document
      has_many  :swaps, class_name: 'Swap', inverse_of: :day

      field :d, as: :date, type: Date
      field :n, as: :name, type: String
      #validates_presence_of :d,:n
      validates_uniqueness_of :d
      validate :date_is_a_trading_day

      before_save do |document|
        unless document.nil?
          document.d ||= DateTime.parse(document.n)
          document.n ||= document.d.strftime('%Y-%m-%d')
        end
      end

      def date_is_a_trading_day
        errors.add(:date, "Date must be a trading day, i.e. #{self.d.strftime('%a, %Y-%m-%d')}") if [0,6].include?(self.d.wday) or Cotcube::Bardata.holidays.include?(self.d)
      end

      def self.today
        Day.find_by(d: Date.today)
      end

      def self.yesterday
        date = Date.yesterday
        begin
          retries ||= 0
          return Day.find_by(d: date - retries)
        rescue
          retry if (retries += 1) < 6
        end
        raise RuntimeError"Could not find a valid day before #{date}"
      end

      def self.method_missing(method, *args, &block)
        m = method.to_s.upcase
        # check whether m has acceptable format
        super unless (foo, year, month, day = m.split(/D(20[0-9]{2})[-]?([0-1][0-9])[-]?([0-3][0-9])/)).size == 4
        days = Days.where(n: "#{year}-#{month}-#{day}")
        super if days.count == 0
        days.first
      end



    end
    Days = Day
  end
end
