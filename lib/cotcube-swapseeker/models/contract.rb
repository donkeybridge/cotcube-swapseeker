module Cotcube
  module SwapSeeker
    class Contract

      include Mongoid::Document
      has_many :swaps, class_name: 'Swap', inverse_of: :contract
      belongs_to :asset, class_name: 'Asset', inverse_of: :contract
      # has_many :signals   # talking about COT signals here

      field :s, as: :sign, type: String # e.g. CLH22
      field :f, as: :first, type: Date
      field :l, as: :last, type: Date

      validates_presence_of :asset
      validates_uniqueness_of :s

      %i[ sym ticksize power months name].each {|m|
        define_method(m) { self.asset.send(m) }
      }

      def to_tick(x); (x / ticksize).round * ticksize;              end

      def self.method_missing(method, *args, &block)
        m = method.to_s.upcase
        super unless [2,3,5].include? m.size
        contracts = Contracts.where( :s => /#{m}/)
        super if contracts.count == 0
        contracts.size==1 ? contracts.first : contracts
      end

      def synthetics
        @synthetics ||= Cotcube::Bardata.provide contract: @sign, interval: :synthetic
      end

    end

    Contracts = Contract
  end
end
