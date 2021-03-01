module Cotcube
  module SwapSeeker
    class Swap

      include Mongoid::Document
      belongs_to :day,      class_name: 'Day',      inverse_of: :swap
      belongs_to :contract, class_name: 'Contract', inverse_of: :swap
      embeds_many :members, class_name: 'Member',   inverse_of: :swap
      #embeds_one :calculus

      field :d, as: :deg,     type: Float
      field :l, as: :length,  type: Integer
      field :x, as: :raw,     type: Array
      field :s, as: :slope,   type: Float
      field :r, as: :rating,  type: Integer
      field :t, as: :type,    type: StringifiedSymbol
      field :c, as: :custom,  type: String # might be set if needed

      validates_presence_of :day, :contract, :deg, :length, :slope, :rating, :type
      validate :has_valid_type
      validates_associated :day, :contract, :members
      validates_with 

      %w[ upper lower rth rtc full rthc custom ].each do |m|
        define_method("#{m}?".to_sym){ self.t.to_s.split('_').include? m }
      end

      def has_valid_type
        unless self.t.to_s.split('_').size == 2
          errors.add(:t, "Must contain 2 parts, i.e. side and swaptype, e.g.  :rth_upper or :upper_rth")
        end
        unless self.t.to_s.split('_').include?('upper') ^ self.t.to_s.split('_').include?('lower')
          errors.add(:t, "Must include either _upper_ or _lower_, e.g. :rth_upper or :upper_rth")
        end
        unless %w[ full rth rtc rthc custom ].map{|x|  self.t.to_s.split('_').include?(x) }.reduce(:|)
          errors.add(:t, "Must include either _full_, _rth_, _rtc_, _rthc_ or _custom_, e.g. :rth_upper or :upper_rth")
        end
        unless self.t.to_s.split('_').include?('custom') ^ self.custom.nil?
          errors.add(:c, "Can only be set if type includes _custom_, but must be set then.")
        end

      end

    end

    Swaps = Swap
  end
end
