module Cotcube
  module SwapSeeker
    class Swap

      # please note https://docs.mongodb.com/mongoid/current/tutorials/mongoid-relations/
      #
      # Note that autosave functionality will automatically be added to an association when
      # using accepts_nested_attributes_for or validating presence of the association.
      #
      # If no :dependent option is provided, deleting the parent record leaves the child
      # record unmodified, possibly orphaned (so use :restrict_with_exception or _error)

      include Mongoid::Document
      belongs_to  :day,      class_name: 'Day',      inverse_of: :swap, index: true
      belongs_to  :contract, class_name: 'Contract', inverse_of: :swap, index: true
      embeds_many :members,  class_name: 'Bar',      inverse_of: :swap
      # embeds_one  :slope,    class_name: 'Slope',    inverse_of: :swap
      # embeds_one  :slope,    class_name: 'Slope',    inverse_of: :swap, as: :guess
      # embeds_one  :calculus

      field :r, as: :raw_string,     type: String #
      field :d, as: :deg,     type: Float  # Winkel
      field :s, as: :slope,   type: Float  # Anstieg
      field :t, as: :type,    type: StringifiedSymbol
      field :c, as: :custom,  type: String # might be set if needed

      validates_presence_of :day, :contract, :type, :deg, :slope
      validate :has_valid_type
      validate :is_unique_for_day_contract_type_and_raw
      validates_associated :day, :contract, :members

      %w[ upper lower frth rtc rthc custom ].each do |m|
        define_method("#{m}?".to_sym){ self.t.to_s.split('_').include? m }
      end

      %w[ rth full ].each do |m|
        define_method("#{m}?".to_sym){ self.t.to_s.split('_').include?(m) or self.t.to_s.split('_').include('frth') }
      end

      def has_valid_type
        unless self.t.to_s.split('_').size == 2
          errors.add(:t, "Must contain 2 parts, i.e. side and swaptype, e.g.  :rth_upper, got #{self.t}")
        end
        unless %w[upper lower].include? self.t.to_s.split('_').last
          errors.add(:t, "last part of type must be the side, got #{self.t}")
        end
        unless self.t.to_s.split('_').include?('upper') ^ self.t.to_s.split('_').include?('lower')
          errors.add(:t, "Must include either _upper_ or _lower_, e.g. :rth_upper or :upper_rth")
        end
        unless %w[ frth full rth rtc rthc custom ].map{|x|  self.t.to_s.split('_').include?(x) }.reduce(:|)
          errors.add(:t, "Must include either _frth_, _full_, _rth_, _rtc_, _rthc_ or _custom_, e.g. :rth_upper or :upper_rth")
        end
        unless self.t.to_s.split('_').include?('custom') ^ self.custom.nil?
          errors.add(:c, "Can only be set if type includes _custom_, but must be set then.")
        end
      end

      def is_unique_for_day_contract_type_and_raw
        errors.add(:raw, "Must be unique for day #{self.day.n
                                     }, contract #{self.contract.s
                                         }, type #{self.type
                                       } and raw #{self.raw.join(' ,')}.") unless Swap.where( contract: self.contract,
                                                                                              day:      self.day,
                                                                                              type:     self.type,
                                                                                              r:        self.r ).all.size.zero?
      end

      def save_or_make_frth
        s = Swap.where( contract: self.contract,
                        day:      self.day,
                        r:        self.r )
        type, side = self.type.to_s.split('_')

        # swaps of special type are ignored for frth
        if %w[rtc rthc custom].include? type
          self.save!
          return true
        end

        case s.count
        when 0
          # no comparable swap exists
          self.save!

        when 1
          # one comparable exists
          # -- but this is the same like me, so no need to save
          if s.first.t == self.t
            puts 'Found same swap twice, ignoring'
            return true
          end

          # -- and it's a valid one
          puts "found comparable #{type}"
          first = s.first
          first.type = "frth_#{side}".to_sym
          if self.validate
            first.save!
          else
            first.errors.full_messages.each{|x| puts x}
            raise RuntimeError, 'Could not validate swap for saving'
          end
        when 2
          puts 'existing frth found'
          first = s.first
          last  = s.last
          last.type = "frth_#{side}".to_sym
          puts last.to_human
          puts first.delete
          last.save!
        else
          raise 'Too many swaps with equal properties'
        end
        return true
      end

      def asset
        @asset ||= self.contract.asset
      end

      def date
        @date ||= self.day.date
      end

      def raw
        @raw ||= JSON.parse(self.raw_string)
      end

      def rating
        @rating ||= self.raw[1..-2].map{|dot| [ dot - self.raw[0], self.raw[-1] - dot].min }.max
      end

      def length
        @length ||= (self.members.sort_by{|x| x.dt}.last.dt.to_date - self.members.sort_by{|x| x.dt}.first.dt.to_date).to_i
      end


      def color
        rat = self.rating
        (rat > 75) ? :light_blue : (rat > 30) ? :magenta : (rat > 15) ? :light_magenta : (rat > 6) ? :light_green : :light_yellow 
      end

      def sorted_members
        @sorted_members ||= self.members.sort_by{|x| x.dt}
      end

      def member_dates
        @member_dates ||= sorted_members.map{|x| x.dt.strftime('%Y-%m-%d')}
      end

      def show_members
        self.sorted_members.each do |m|
          puts "#{m.dt_utc.strftime('%Y-%m-%d')
             }\t#{format '%3d', m.x.to_i
             }\t#{format '%7.4f', m.dx
             }\t#{format '%3d', m.i
             }\t#{self.asset.fmt m.y
             }\t#{(self.asset.fmt m.h).colorize(upper? ? :light_white : :white)
             }\t#{(self.asset.fmt m.l).colorize(lower? ? :light_white : :white)
             }\t#{format '% 8d', m.v
             }"
        end
      end

      def to_human
        "#{self.contract.s
          }\t#{self.day.n
          }\t#{format '%10s', self.asset.fmt(sorted_members.last.send(self.t.to_s =~ /upper/ ? :h : :l))
          }\t#{format '%3d', self.rating} | #{format '%3d', self.length}".colorize(self.color) +

          "\t#{(format '%12s', self.type).colorize(self.type =~ /upper/ ? :light_green : :light_red)
          }\t#{sorted_members.first.dt.strftime('%m-%d')
          }\t#{self.asset.fmt sorted_members.first.send(self.t.to_s =~ /upper/ ? :h : :l)
          }\tothers: #{sorted_members[1...-1].map{|x| x.dt.strftime('%Y-%m-%d')}.join('  ')
          }"
      end

      def show(rating: 7, steep: true)
        puts self.to_human if self.rating >= rating or (steep ? self.steep? : false)
      end


      def self.show_all_with_more_than_8_members
        Swap.collection.find({ "members.8" =>  { "$exists" => true } })          # returns a cursor that iterates over BSON documents (hashes, containing x['_id'])
          .each {|x| puts Swaps.find(id: x['_id']).to_human }                    # finds the correspoding Mongoid Document by its id
      end

      def steep?
        mem_sorted = self.members.sort_by{|x| x.dt}
        mem_sorted.first.dt >= mem_sorted.last.dt - (self.members.size * 2.5).floor.days
      end

      def self.show_all_steep(after: nil)
        Swap.collection.find({ "members.4" =>  { "$exists" => true } })
          .map{|x| Swaps.find(id: x['_id']) }
          .select{|sw| (after.nil? ? true : sw.day.d >= after) and sw.steep? }
          .sort_by{|x| x.contract.type}.sort_by{|x| x.contract.s[0..1]}.sort_by{|x| x.day.n}.each {|x| puts x.to_human }
      end

      def self.show_all_of_last_14_days
        Day.where(:d.gt => Date.today - 14).map{|x| x.swaps}.flatten.sort_by{|x| x.contract.type}.sort_by{|x| x.contract.s[0..1]}.each {|x| puts x.to_human if x.rating > 12 }
      end




    end
    Swaps = Swap
  end
end
