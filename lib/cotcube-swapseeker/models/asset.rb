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
    end

    Assets = Asset
  end
end
