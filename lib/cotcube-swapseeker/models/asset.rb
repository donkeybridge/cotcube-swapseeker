module Cotcube
  module SwapSeeker
    class Asset

      attr :symbol

      include Mongoid::Document
      has_many :contracts, class_name: 'Contract', inverse_of: :asset
      field :s, as: :symbol, type: String
      validates_uniqueness_of :s

      def sym;      @sym ||= Cotcube::Bardata.get_id_set(symbol: @symbol); end
      def ticksize; @sym[:ticksize];                                end
      def power;    @sym[:power];                                   end
      def months;   @sym[:months];                                  end
      def name;     @sym[:name];                                    end
      def to_tick(x); (x / ticksize).round * ticksize;              end
      def fmt(x);   true; end


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
