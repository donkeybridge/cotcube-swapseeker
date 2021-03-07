# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    class Stencil
      attr_accessor :base
      attr_reader   :swaps


      # Class method that loads the (latest) obligatory stencil for given interval and type.
      # These raw stencils are located in /var/cotcube/swapseeker/stencils
      #
      # Current daily stencils contain dates from 2020-01-01 to 2023-12-21
      #
      def self.provide_raw_stencil(type:, interval: :daily, version: nil)
        loading = lambda do |typ|
          file_base = "/var/cotcube/swapseeker/stencils/stencil_#{interval.to_s}_#{typ.to_s}.csv_"
          if Dir["#{file_base}?*"].empty?
            raise ArgumentError, "Could not find any stencil matching interval #{interval} and type #{typ}. Check #{file_base} manually!"
          end
          if version.nil? # use latest available version if not given
            file = Dir["#{file_base}?*"].sort.last
          else
            file = "#{file_base}#{version}"
            unless File.exist? file
              raise ArgumentError, "Cannot open stencil from non-existant file #{file}."
            end
          end
          CSV.read(file).map{|x| {datetime: CHICAGO.parse(x.first), x: x.last.to_i.freeze } }
        end
        unless const_defined? :RAW_STENCILS
          const_set :RAW_STENCILS, { daily:
                                     { full: loading.call( :full).freeze,
                                       rtc:  loading.call( :rtc).freeze
          }.freeze
          }.freeze
        end
        RAW_STENCILS[interval][type]
      end

      def initialize(
        range: nil,                 # used to shrink the stencil size, accepts String or Date
        interval:,
        swap_type:,
        ranges: nil,                # currently not used, prepared to be used in connection intraday
        contract: nil,
        today: nil,                 # today and now are mutually exclusive, being used with dailies in the first, with intraday in latter case
        debug: false,
        version: nil,               # when referring to a specicic version of the stencil
        timezone: CHICAGO,
        stencil: nil,               # instead of loading, use this data
        config: init
      )
        @debug     = debug
        @interval  = interval
        @swap_type = swap_type
        @swaps     = []
        @contract  = contract
        step =  case @interval
                when :hours, :hour; 1.hour
                when :quarters, :quarter; 15.minutes
                else; 1.day
                end

        case @interval
        when :day, :days, :daily, :dailies, :synth, :synthetic #, :week, :weeks, :month, :months
          unless range.nil?
            starter = range.begin.is_a?(String) ? timezone.parse(range.begin) : range.begin
            ender   = range.  end.is_a?(String) ? timezone.parse(range.  end) : range.  end
        end

        stencil_type = case swap_type
                       when :rth
                         :full
                       when :rthc
                         :rtc
                       else
                         swap_type
                       end
        # TODO: Check / warn / raise whether stencil (if provided) is a proper data type
        raise ArgumentError, "Stencil should be nil or Array" unless [NilClass, Array].include? stencil.class
        raise ArgumentError, "Each stencil members should contain at least :datetime and :x" unless stencil.nil? or
          stencil.map{|x| ([:datetime, :x] - x.keys).empty? and x[:datetime].is_a?(ActiveSupport::TimeWithZone) and x[:x].is_a?(Integer)}.reduce(:&)

        base = stencil || Stencil.provide_raw_stencil(type: stencil_type, interval: :daily, version: version)

        # fast forward to prev trading day
        @today = today || Date.today
        best_match = base.select{|x| x[:datetime].to_date <= @today}.last[:datetime]
        @today  = best_match

        offset = base.map{|x| x[:datetime]}.index(@today)

        # apply offset to stencil, so zero will match today (or what was provided as 'today')
        @base = base.map.
          each_with_index{|d,i| { datetime: d[:datetime].freeze, x: (offset - i ).freeze } }
        # if range was given, shrink stencil to specified range
        @base.select!{|d| (d[:datetime] >= starter and d[:datetime] <= ender) } unless range.nil?
      else
        raise RuntimeError, "'interval: #{interval}' was provided, what does not match anything this tool can handle (currently :days, :dailies, :synthetic)."
      end
    end

    def dup
      Stencil.new(
        debug:      @debug,
        interval:   @interval,
        swap_type:  @swap_type,
        today:      @today,
        contract:   @contract,
        stencil:    @base.map{|x| x.dup}
      )
    end


    def zero
      @zero ||=  @base.find{|x| x[:x].zero? }
    end

    def stencil
      @base
    end

    def swaps=(swaps)
      puts "WARNING: overwriting existing swaps!".light_yellow unless @swaps.nil?
      @swaps = swaps
    end

    # convenient output of stencil data and attached swaps (if any)
    def inspect
      "#<Stencil:0x0815> @contract:#{@contract} @interval:#{@interval} @swaps:#{@swaps.size} @base:#{@base.size} today:#{@today}" +
        @swaps.each_with_index.map { |swap,i|
        len = swap[:members].first[:x] + 1
        mem = swap[:members].size
        # the guess stencil is quite overloaded, but I don't have access to a stencil with future dates yet at this point
        guess_stencil  = Stencil.
          new( interval: :synthetic, swap_type: @swap_type, debug: @debug, today: @today, contract: @contract ).
          stencil.
          select{|s| s[:x] < 0}.
          first

        puts "GS: #{guess_stencil}"  if @debug
        rat = swap[:rating]
        col = (rat > 30) ? :magenta : (rat > 15) ? :light_magenta : (rat > 6) ? :light_green : swap[:rated] ? :light_yellow : :yellow

        "\n\t\tswap #{i}: len:#{    format '%3d', len
                         } rating:#{  format '%2d', swap[:rating]
                         } mem:#{     format '%2d', mem
                         } deg:#{     format '%4.2f', swap[:deg]
                         } first:#{   swap[:members].first[:datetime].strftime("%Y-%m-%d")
                         } last:#{    swap[:members].last[:datetime].strftime("%Y-%m-%d")
                         } current: #{swap[:actual].call(0)
                         } guess: #{  swap[:guess].call(guess_stencil[:x]+1).round(8)
                         } for: #{    guess_stencil[:datetime].strftime('%Y-%m-%d')
                         }".colorize( col )
        }.join
      end

      # calls the calculus for each attached swap
      def calculus(number=nil)
        if @swaps.empty?
          puts "No swaps in stencil!".light_red
        else
          if number.nil?
            @swaps.each_with_index do |swap, i|
              puts "Presenting swap [#{i}]".light_green
              swap[:calculus].call(members: swap[:members].map{|x| x[:x]} )
            end
          else
            puts "Presenting swap [#{number}]".light_green
            @swaps[number][:calculus].call(members: @swaps[number][:members].map{|x| x[:x]} )
          end
        end
      end

      def inject_base(contract:, base: nil, range: (0..-1))
        integer_range = ((range.is_a?(Range)) and ((range.begin.is_a?(Integer)) || range.end.is_a?(Integer)))
        sym = Cotcube::Bardata.get_id_set(contract: contract)
        base ||= Cotcube::Bardata.provide contract: contract, interval: @interval, filter: @filter, range: (integer_range ? nil : range)
        base = base[range] if integer_range
        offset = 0
        base.each_with_index do |_,i|
          begin
            offset += 1 while @base[i+offset][:datetime] < base[i][:datetime]
          rescue Exception => ex
            puts("ERROR processing #{i} + #{offset} on #{@base[i+offset]} vs #{base[i]}")
            puts("======= ERROR: '#{ex.class}', MESSAGE: '#{ex.message}'")
            puts "WARNING: Holiday found. skipping!".light_yellow
            next
          end
          if @base[i+offset][:datetime] > base[i][:datetime]
            puts "skipping #{base[i]}".light_yellow if @debug
            offset -= 1
            next
          end
          j = i + offset
          # the following line does the actual injection
          # NOTE: for each node, data is only injected, if it only contains the
          #       basice keys :datetime and :x
          @base[j] = @base[j].merge(base[i]) if @base[j].keys.size == 2
        end
      end

      def show_members
        @swaps.each_with_index do |swap, index|
          swap[:members].each do |member|
            puts "#{index}\t#{member[:datetime].strftime('%a %Y-%m-%d')} #{member[:contract]
               }\t#{member[:high]}\t#{member[:x]}\t#{member[:dx].round(4)}\t#{member[:i]}"
          end
        end
      end

    end

  end

end

