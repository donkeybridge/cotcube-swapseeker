module Cotcube
  module SwapSeeker
    class Asset

      include Mongoid::Document
      has_many :contracts, class_name: 'Contract', inverse_of: :asset
      field :s, as: :symbol, type: String

      validates_uniqueness_of :s

      def sym;      @sym ||= Cotcube::Bardata.get_id_set(symbol: s); end
      def ticksize; self.sym[:ticksize];                             end
      def power;    self.sym[:power];                                end
      def months;   self.sym[:months];                               end
      def name;     self.sym[:name];                                 end
      def type;     self.sym[:type];                                 end
      def to_tick(x); (x / ticksize).round * ticksize;               end

      def fmt(number=nil)
        number.nil? ? self.sym[:format] : format(self.sym[:format], number)
      end

      def self.method_missing(method, *args, &block)
        m = method.to_s.upcase
        assets = Asset.where( s: m )
        super if assets.count.zero?
        assets.first 
      end

      def swaps(after: nil, before: nil, rating: 7, steep: false)
        self.contracts.
          active.
          map{|x| x.swaps }.
          flatten.
          select{|sw|
            (after.nil?    ? true : sw.day.d >= after) and
              (before.nil? ? true : sw.day.d <= before) and
              ((sw.rating > rating) or (steep ? sw.steep? : false))
          }.
          sort_by{|x| x.day.n}
      end

      def self.all_recent(range: (0..-1), rating: 7, steep: false)
        r_begin = range.begin
        r_end   = range.end
        r_begin = (Date.today + (r_begin.zero? ? -1000 : r_begin)) unless r_begin.is_a? Date
        r_end   = (Date.today + r_end)   unless r_end.is_a? Date
        self.all.sort_by{|a| a.s }.sort_by{|a| a.type }.each do |asset|
          puts "--- #{asset.s} --- #{format '%20s', asset.type} ---  ".light_white
          asset.swaps(after: r_begin, before: r_end, rating: rating, steep: steep).each do |sw|
            sw.show(rating: rating, steep: steep)
          end
        end
      end
    end

    Assets = Asset
  end
end
