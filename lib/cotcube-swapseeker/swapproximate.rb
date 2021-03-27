# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    ##############################################3
    # 
    # the following method just call swapproximate_eod for the 300 days before given date
    # based on provided types of stencils (full, rtc) and sides (upper, lower) each combo is iterated
    #
    ###############################################
    def swapproximate_run(
      date: Date.yesterday,
      contract:,
      holidays: Cotcube::Bardata.holidays.map{|day| day.to_date },
      debug: false,
      types: nil,
      sides: nil,
      pre: 300
    )
      known_types = %i[full rtc rth rthc]
      known_sides = %i[upper lower]
      types ||= known_types
      sides ||= known_sides
      types = [ types ] unless types.is_a? Array
      sides = [ sides ] unless sides.is_a? Array
      raise ArgumentError, "Unknown stencil types '#{types - known_types}'." unless (types - known_types).empty?
      raise ArgumentError, "Unknown stencil types '#{sides - known_sides}'." unless (sides - known_sides).empty?

      date -= pre
      300.times do
        date += 1
        next if [0,6].include?(date.wday) or holidays.include?(date)
        s = swapproximate_eod(date: date, contract: contract, holidays: holidays, debug: debug, sides: sides, types: types)
        if (not s) or s.empty?
          puts "No swaps to display." 
        else
          s.each {|k,v| puts "#{k}\t#{v.inspect}"}
          if s.map{|_,v| v.swaps}.flatten.map{|x| x[:rated]}.reduce(:|)
            puts "press enter to continue"
            STDIN.gets
          end

        end
      end
    end


    def swapproximate_eod(
      date: Date.yesterday, 
      symbol: nil,
      contract: nil,
      holidays: Cotcube::Bardata.holidays.map{|day| day.to_date },
      keep: false,
      debug: false,
      types: nil,
      sides: nil,
      measure: false
    )


      #############################################################################
      #
      # in first place we have to set:
      #     1. the date, which is processed
      #     2. the contract, if not given
      #     3. the base, according to contract
      #     4. and maybe warn or err if there is some mismatch inbetween.
      #
      #############################################################################

      t0 = Time.now.to_f
      measuring = lambda {|c| puts "Time measured until '#{c}': #{(Time.now.to_f - t0).round(2)}sec" if measure }
      known_types = %i[full rtc rth rthc]
      known_sides = %i[upper lower]
      types ||= known_types
      sides ||= known_sides
      types = [ types ] unless types.is_a? Array
      sides = [ sides ] unless sides.is_a? Array
      raise ArgumentError, "Unknown stencil types '#{types - known_types}'." unless (types - known_types).empty?
      raise ArgumentError, "Unknown stencil types '#{sides - known_sides}'." unless (sides - known_sides).empty?
 
      date = Date.parse(date.to_s) if [Symbol,String].include? date.class
      date -= 1 while [0,6].include?(date.wday) or holidays.include?(date)

      puts "Running swapproximate for "+date.strftime("%a, %Y-%m-%d").light_white
      sym  = Cotcube::Bardata.get_id_set contract: contract, symbol: symbol

      measuring.call("Requesting most_liquid for #{contract}")

      ###############################################################################
      #
      # The following section 'only' consults the best option in regards of the 
      #     currently most liquid contract and warns if not fit
      #
      ###############################################################################

      ml   = Cotcube::Bardata.continuous_table symbol: sym[:symbol], date: date
      measuring.call("Retrieved most_liquid for #{contract}")

      if (ml.size != 1 and contract.nil?)
        puts "WARNING: No or no unique most liquid found for #{date}. please give :contract parameter".light_yellow
        if ml.size > 1
          puts "\tUsing #{ml.last}. Consider breaking here, if that is not acceptable.".light_yellow
          sleep 1
        else
          puts "\tGiving up, no option provided.".light_red
          return []
        end
      end
      year = date.year % 100
      unless ml.empty?
        if ml.last[2] < "K" and date.month > 9
          suggested_contract = "#{ml.last}#{year + 1}"
        else
          suggested_contract = "#{ml.last}#{year}"
        end
      end
      date = date.to_date unless date.is_a? Date
      contract ||= suggested_contract
      puts "Using #{contract}" if debug

      #############################################################################
      #
      # Price date retrievel
      #
      #############################################################################

      base = Cotcube::Bardata.provide contract: contract, interval: :synthetic
      puts "Base.first is: #{base.first.values_at *%i[contract date volume]}" if debug
      puts "Base.last  is: #{base. last.values_at *%i[contract date volume]}" if debug

      if base.last[:datetime] < date 
        puts "Cannot use date #{date} with current base, as base of #{contract} is too old for processing!".light_red
        return []
      elsif (not suggested_contract.nil?) and contract != suggested_contract
        puts "Suggesting #{suggested_contract} instead of #{contract}.".light_white
      end

      measuring.call("Beginning of stage 2(stencil generation)")
      result = {} 

      # furthermore this is done for each combo of 'swaptype and side' 
      types.each do |swap_type|
        sides.each do |side|

	  combo = "#{swap_type.to_s}_#{side.to_s}"

          ###################################################################################
          #
          # The next step is generating the stencil and enriching it using the base data
          #    please note, that there is the day 'first', the day 'zero' and the day 'last'
          #    and the stencil provided lasts from day 'first' to 100 days after day 'last',
          #    while 'zero' remains the day where x is zero (commonly yesterday is zero)
          #
          #    this is important is zero is the focal point or pivot point
          #
          #####################################################################################


          stencil  = Stencil.new( interval: :synthetic, swap_type: swap_type, debug: debug, date: date, contract: contract )
          measuring.call("Stencil for #{combo} created")
	  # rth calculation begins 100 days before first appearance in ML, hence data earlier on is filled with daily data
          if [:rth, :rthc].include? swap_type
            rth_base = Cotcube::Bardata.provide contract: contract, interval: :days, filter: :rth
            stencil.inject_base(contract: contract, base: rth_base)
          end
          stencil.inject_base(contract: contract, base: base)
          stencil.stencil.select! do |x| 
            x[:datetime] >= base.first[:datetime] and 
              x[:datetime] <  base.last[:datetime] + 100.days
          end
          if stencil.zero.nil? 
            puts "ERROR: Stencil out of range for date #{date} and contract #{contract}, please use suggested contract!".colorize(:light_red)
            return []
          end
          stencil.stencil.map! do |day| 
            if day[:high] or day[:low]
              day[:y] =
                (side == :upper ?
                 (day[:high] - stencil.zero[:high]).round(9) :
                 (stencil.zero[:low] - day[:low]).round(9)
                )
            end
            day
          end
          result[combo]           = stencil
          measuring.call("Stencil for #{combo} enriched")

          ################################################################################
          #
          # next step is to load currently contracts swap_history and to check whether
          #    1. which swaps ended yesterday
          #    2. which swaps are confirmed or approached
          #
          ################################################################################

          ################################################################################
          #
          # next step is to detect new swaps, create according output
          #
          ################################################################################


          measuring.call("Beginning of stage 4 (detecting new swaps)")

          combo = "#{swap_type.to_s}_#{side.to_s}"
          puts "DEBUG in swapproximate: detecting within '#{combo}'." if debug
          result[combo].swaps = triangulate(base: result[combo].base, deviation: 2, once: false, side: side, debug: debug, contract: contract)
          puts "DEBUG in swapprocimate: detection for '#{combo}' finished" if debug
          result.delete(combo) if result[combo].swaps.empty? and not keep

        end
      end

      result
    end
  end
end

