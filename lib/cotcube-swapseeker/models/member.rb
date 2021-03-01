module Cotcube
  module SwapSeeker
    class Member

      include Mongoid::Document
      embedded_in :swap, class_name: 'Swap', inverse_of: :member
      field :dt, as: :datetime, type: Date
      field :x, type:  Integer
      field :dx, type: Float
      field :i, type: Integer
      field :h, as: :high, type: Float
      field :l, as: :low, type: Float
      field :v, as: :volume, type: Integer
      field :oi,  type: Integer

      validates_presence_of :x, :i, :h, :l, :dt
      validate :floats_are_not_fragments
      validate :high_is_higher_than_low

      def high_is_higher_than_low
        errors.add(:h, "Cannot accept low being higher than high #{self.l} > #{self.h}") if self.l > self.h
      end

      def floats_are_not_fragments
        [ self.dx, self.h, self.l ].each do |value|
          errors.add(:h, "The value '#{value}' is fragmented. Please fix before saving to DB") unless value.nil? or value == value.round(8)
        end
      end

    end

    Members = Member
  end
end
