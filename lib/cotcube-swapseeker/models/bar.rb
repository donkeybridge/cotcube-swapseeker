# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    class Bar

      attr_accessor :yy

      include Mongoid::Document
      embedded_in :line, class_name: 'Line', inverse_of: :dot
      
      field :dt, as: :datetime, type: Date
      field :x,  type: Float
      field :dx, type: Float
      field :y,  type: Float
      field :i,  type: Integer
      field :h,  as: :high, type: Float
      field :l,  as: :low,  type: Float
      field :v,  as: :volume, type: Integer
      field :oi, type: Integer

      validates_presence_of :dt, :x, :dx, :y, :i, :h, :l

      def [](key)
        super unless [:yy].include? key
        self.send(key)
      end

      def []=(key, value)
        super unless[:yy].include? key
        self.send("#{key}=".to_sym, value)
      end

      def merge(set)
        set.keys.each {|x| self[x] = set[x] if [:high,:low,:volume,:oi].include? x}
        set
      end

    end

    Bars = Bar
  end
end

