# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    class Stencil
      attr_accessor :base
      attr_reader   :swaps


      def self.provide_raw_stencil(type:, interval: :daily, version: nil)
        file_base = "/var/cotcube/swapseeker/stencils/stencil_#{interval.to_s}_#{type.to_s}.csv_"
        if Dir["#{file_base}?*"].empty?
          raise ArgumentError, "Could not find any stencil for interval #{interval} and type #{type}. Check #{file_base} manually!"
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

      def add_boundaries
        @swaps.each do |swap|
          p swap
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


      def initialize(
        range: nil,
        interval:,
        swap_type:,
        ranges: nil,
        contract: nil,
        today: nil,
        now: nil,
        debug: false,
        version: nil,
        timezone: CHICAGO,
        config: init
      )
        @debug    = debug
        @interval = interval
        @swap_type = swap_type
        @swaps    = nil
        @contract = contract
        step =  case interval
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
          @base = Stencil.provide_raw_stencil(type: stencil_type, interval: :daily, version: version)

          # fast forward to prev trading day
          @today = today || Date.today
          best_match = @base.select{|x| x[:datetime].to_date <= @today}.last[:datetime]
          @today  = best_match

          offset = @base.map{|x| x[:datetime]}.index(@today)

          @base
            .map!
            .each_with_index{|d,i| { datetime: d[:datetime].freeze, x: (offset - i ).freeze } }
          @base
            .select!{|d| (d[:datetime] >= starter and d[:datetime] <= ender) } unless range.nil?
        else
          raise RuntimeError, "'interval: #{interval}' was provided, what does not match anything this tool can handle (currently :quarters, :hours, :days)."
        end
      end

      def zero
        @zero ||=  @base.select{|x| x[:x].zero? }.first
      end

      def stencil
        @base
      end

      def swaps=(swaps)
        puts "WARNING: overwriting existing swaps!".light_yellow unless @swaps.nil?
        @swaps = swaps
      end

      def inspect
        "#<Stencil:0x0815> @contract:#{@contract} @interval:#{@interval} @swaps:#{@swaps.size} @base:#{@base.size} today:#{@today}" +
          @swaps.each_with_index.map { |swap,i|
          len = swap[:members].first[:x] + 1
          mem = swap[:members].size
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
            puts "Presenting swap [#{n}]".light_green
            @swaps[n][:calculus].call(members: @swaps[n][:members].map{|x| x[:x]} )
          end
        end
      end


      def inject_base( contract:, base: nil, range: (0..-1))
        integer_range = ((range.is_a?(Range)) and ((range.begin.is_a?(Integer)) || range.end.is_a?(Integer)))
        sym = Cotcube::Bardata.get_id_set(contract: contract)
        base ||= Cotcube::Bardata.provide contract: contract, interval: @interval, filter: @filter, range: (integer_range ? nil : range)
        base = base[range] if integer_range
        offset = 0
        base.each_with_index do |_,i|
          #puts "BASE: #{base[i][:datetime]}" if @debug
          #puts  "#{stencil[i+offset][:datetime]} < #{base[i][:datetime]}" if @debug
          begin
            while @base[i+offset][:datetime] < base[i][:datetime]
              #puts "skipping #{@base[i+offset][:datetime]}".yellow if @debug
              offset += 1
            end
          rescue
            # I dont know why but for holidays it fails
            puts "WARNING: Holiday found. skipping!".light_yellow
            #return { upper: [], lower: [] }
          end
          if @base[i+offset][:datetime] > base[i][:datetime]
            puts "skipping #{base[i]}".light_yellow if @debug
            offset -= 1
            next
          end
          j = i + offset
          #puts "#{i}\t#{offset}" if @debug
          #puts "ST: #{stencil[j][:datetime]}" if @debug
          @base[j] = @base[j].merge(base[i]) if @base[j][:volume].nil?
          #puts "->: #{@base[j]}\n\n" if @debug
        end
      end
    end
  end
end

