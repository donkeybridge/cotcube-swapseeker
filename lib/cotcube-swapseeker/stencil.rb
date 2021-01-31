# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    def stencil(range:,               # (start..end) of the stencil (normally the range of the provided bars
                interval:,            # the bar size (15.minutes ... 1.day etc)
                ranges: nil,              # badly named, but: the result of Bardata.trading_hours for contract X filter
                # ranges is not needed for intervals gte 1.day
                swap_type:,           # :full, :rth, :_24x7_, :<custom>
                today: nil,           # set the date, which receives x=0, defaults to last if omitted
                now: nil,             # alternative to 'today'
                include_holidays: false, # whether the swap grows during holidays (non-business-hours), default: false
                config: init)
      puts "WARNING: ".colorize(:light_yellow) + 'ranges ignored as interval is >= 1.day' unless ranges.nil? or not [:quarter, :quarters, :hour, :hours].include? interval
      unless ranges.nil? 
        # checking whether ranges is a viable array of ranges of integer
        raise ArgumentError, ":ranges is expected to be an Array if given" unless ranges.is_a? Array
        raise ArgumentError, ":ranges is expected to be an Array of ranges if given" unless ranges.map{|x| x.is_a? Range}.reduce(:&)
        raise ArgumentError, ":ranges is expected to be an Array of ranges of Integers" unless ranges.map{|x| x.begin.is_a?(Integer) and x.end.is_a?(Integer) }.reduce(:&)
      end
      ranges_24x7 = [(0...604_800)]
      ranges_full = [
        62_200...144_000,   # Sun 5pm .. Mon 4pm CT
        147_600...230_400,  # Mon 5pm .. Tue 4pm CT
        234_000...316_800,  # ...
        320_400...403_200,  #
        406_800...489_600   #         .. Fri 4pm CT
      ]

      step =  case interval
              when :hours, :hour; 1.hour
              when :quarters, :quarter; 15.minutes
              else; 1.day
              end

      stencil = range.to_time_intervals(step: step).
        map{|x| [:quarter, :quarters, :hour, :hours].include?(interval) ? x : x.to_date }

      case interval
      when :day, :days, :daily, :dailies, :synth, :synthetic #, :week, :weeks, :month, :months 
        # accepted swap_types _24x7_ (sun - sat) and non-_24x7_ (mon - fri)
        # so if and only of swap_type is _24x7_, dates are _not_ filtered
        unless swap_type == :_24x7_
          # filter what belongs to weekends
          stencil.select!{|x| not [0,6].include?(x.to_date.wday)}
        end
      when :quarter, :quarters, :hours, :hours
        # accepted swap_types are 
        #   :_24x7_ (includes all hours / quarters on weekends) 
        #   :full   (includes :ranges or defaults to 5pm - 4pm, sun - fri)
        #   else    (includes :ranges or raises ArgumentError)
        case swap_type
        when :_24x7_
          applied_ranges = ranges_24x7
        when :full
          applied_ranges = ranges.nil? ? ranges_full : ranges
        else
          raise ArgumentError, "Need :ranges unless :swap_type is :full or :_24x7_" if ranges.nil?
          applied_ranges = ranges
        end
        # NOTE: the following is quite time expensive on huge arrays
        stencil = stencil.select_within(ranges: applied_ranges){ |x| x.to_datetime.to_seconds_since_sunday_morning }
      else
        raise RuntimeError, "'interval: #{interval}' was provided, what does not match anything this tool can handle (currently :quarters, :hours, :days)."
      end

      unless include_holidays # normally, holidays should be cut off the stencil
        holidays = Cotcube::Bardata.holidays.map{|x| x.to_date}
        stencil.select!{|x| not holidays.include?(x.to_date) }
      end

      if now.nil? and today.nil?
        size = stencil.size
        stencil.map.each_with_index{|d,i|  {datetime: d, x: size - i - 1} }
      else
        raise ArgumentError, "Cannot accept both :today and :now for stencil, got #{today} and #{now}" unless now ^ today
        now ||= today
        now = DateTime.parse(now.to_s) unless now.is_a? DateTime
        idx = stencil.index(now)
        raise RuntimeError, "#{now} is not part of stencil, possibly holiday, weekend or outside trading hours" if idx.nil?
        puts idx
        stencil.map.each_with_index{|d, i| {datetime: d, x: idx - i } }
      end
    end

  end
end

