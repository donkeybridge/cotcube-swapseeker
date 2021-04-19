# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    class Bar
      Default_Timezone = 'America/Chicago'
      Hidden_Accessors = [:yy, :dy, :sy, :t, :temp, :member]
      attr_accessor *Hidden_Accessors

      include Mongoid::Document
      embedded_in :swap, class_name: 'Swap', inverse_of: :bar
      
      field :dt_utc, type: DateTime
      field :tz, type: String, default: nil
      field :x,  type: Float
      field :dx, type: Float
      field :y,  type: Float
      field :i,  type: Integer
      field :h,  as: :high, type: Float
      field :l,  as: :low,  type: Float
      field :v,  as: :volume, type: Integer
      field :oi, type: Integer

      validates_presence_of :dt_utc, :x, :dx, :y, :i, :h, :l
      validate :floats_are_not_fragments
      validate :high_is_higher_than_low


      ########################################################################################3
      # The following 5 lines are wrappers that provide access to datetime in actual timezoen
      # whereas mongoid saves DateTimes always in UTC
      #
      # There is a Default Timezone set to 'America/Chicago'
      #
      def timezone; self.tz.nil? ? Default_Timezone : self.tz; end
      def datetime; self.dt_utc.in_time_zone(self.tz.nil? ? timezone : self.tz); end
      def datetime=(some_time); self.dt_utc = some_time.utc; end
      alias_method :dt, :datetime
      alias_method :dt=, :datetime=

      ###########################################################################################
      # Validators
      #
      def high_is_higher_than_low
        errors.add(:h, "Cannot accept low being higher than high #{self.l} > #{self.h}") if self.l > self.h
      end
      def floats_are_not_fragments
        [ :h, :l ].each do |value|
          val = self.send(value)
          errors.add(value, " => The value '#{val}' is fragmented. Please fix before saving to DB") unless val.nil? or val == val.round(8)
        end
      end

      ###########################################################################################
      #
      def present
        "#{datetime.strftime("%a, %Y-%m-%d %H:%M")
                               }  x: #{format '%-4d', self.x
                               } dx: #{format '%-4d', (self.dx.nil? ? self.x : self.dx)
                                  }, #{(self.swap.high ? "high" : "low") unless self.swap.nil?
                                  }: #{(format self.swap?.asset.fmt, (self.upper ? self.high : self.low)) unless self.swap.nil?
                               }, i: #{(format '%4d', self.i) unless self.i.nil?}"
      end


      ##########################################################################################
      # [] and []= are needed to provide Hash-like access to the HiddenAccessors
      #
      def [](key)
        super unless Cotcube::SwapSeeker::Bar::Hidden_Accessors.include? key
        self.send(key)
      end

      def []=(key, value)
        super unless Cotcube::SwapSeeker::Bar::Hidden_Accessors.include? key
        self.send("#{key}=".to_sym, value)
      end

      ##########################################################################################
      # merge is needed to allow seemless operation in inject_base
      #
      def merge(set)
        set.keys.each {|x| self[x] = set[x] if [:high,:low,:volume,:oi].include? x}
        set
      end

      ##########################################################################################
      # due to hidden attributes, #dup needs to duplicate them manually, as they are not
      # considered by mongoid
      #
      def dup
        r = super
        Hidden_Accessors.map{|x| r[x] = self[x]}
        r
      end

    end

    Bars = Bar
  end
end

