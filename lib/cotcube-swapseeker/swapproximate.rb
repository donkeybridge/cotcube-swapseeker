# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    ##############################################3
    # 
    # the following method just call swapproximate_eod for the <pre=90> days before given date
    # based on provided types of stencils (full, rtc) and sides (upper, lower) each combo is iterated
    #
    ###############################################
    def swapproximate_run(
      date: Date.yesterday,
      contract:,
      holidays: Cotcube::Bardata.holidays.map{|day| day.to_date },
      first_ml: nil,
      auto: false,
      debug: false,
      types: %i[full rth],
      sides: nil,
      warnings: true,
      pre: 90
    )
      puts "swapproximate_run is deprecated or needs to be rewritten".light_red
      return false

      first_ml = Cotcube::Bardata.continuous_overview(symbol: contract[0..1])[contract].first[:date]
      date     = Date.parse(first_ml)
      last     = Cotcube::Bardata.provide(contract: contract).last[:datetime].to_date
      known_types = %i[full rtc rth rthc]
      known_sides = %i[upper lower]
      types ||= known_types
      sides ||= known_sides
      types = [ types ] unless types.is_a? Array
      sides = [ sides ] unless sides.is_a? Array
      raise ArgumentError, "Unknown stencil types '#{types - known_types}'." unless (types - known_types).empty?
      raise ArgumentError, "Unknown stencil types '#{sides - known_sides}'." unless (sides - known_sides).empty?

      date -= pre
      while date <= last
        date += 1
        next if [0,6].include?(date.wday) or holidays.include?(date)
        stencils = swapproximate_eod(date: date, contract: contract, holidays: holidays, debug: debug, sides: sides, types: types, warnings: warnings, debug: debug)
        if (not stencils) or stencils.empty?
          puts "No swaps to display." 
        else
          stencils.each do |key,stencil|
            puts "#{key}\t#{stencil.inspect}"
            stencil.swaps.map do |swap|
              if swap[:rated]
                swap.save_or_make_frth
              end
            end
          end
          # if any of the swaps has the attribute 'rated', wait for ENTER
          if not auto and stencils.map{|_,stencil| stencil.swaps}.flatten.map{|swap| swap[:rated]}.reduce(:|)
            puts "Press enter to continue..."
            STDIN.gets
          end

        end
      end
    end

    # the following method is considered the swapproximate EOD, that
    #   1. checks which contracts are currently considered
    #   2. fills all contracts back to the 90 days before first_ml
    #   3. gets the normal eod done
    #   4. retires contracts after their last
    def swapproximate_daily(processes: 5, force_update: false, debug: false)
      types = %i[full rth]
      sides = %i[upper lower]
      holidays = Cotcube::Bardata.holidays.map{|day| day.to_date }
      considerables = Contracts.considerable
      db_monitor = Monitor.new
      expired_contracts = considerables.map{|x| x.s} - Cotcube::Bardata.provide_eods(threshold: 0)
      Cotcube::Helpers.parallelize(considerables.sort_by{|x| x.s[0..1]}.to_a.each_slice(considerables.count / processes), processes: processes) do |chunk|
        chunk.each do |contract|
          puts "Processing #{contract.inspect}".light_white
          if expired_contracts.include? contract.s and not force_update
            puts "#{contract.s} already expired. Use :force_update to force.".light_red
            puts "Currently no decommission of expired updates is enabled\n\n".light_red
            next
          end
          date = contract.first_ml - 91.days
          while date < Date.yesterday
            contract.p ||= date
            date += 1.day
            next if date <= contract.p or
              [0,6].include?(date.wday) or
              holidays.include?(date)
            stencils = swapproximate_eod(date: date, contract: contract.s, holidays: holidays, debug: false, sides: sides, types: types, warnings: false, force_update: force_update, debug: debug)
            if (not stencils) or stencils.empty?
              puts "No swaps to display."
            else
              stencils.each do |key,stencil|
                puts "#{key}\t#{stencil.inspect}"
                stencil.swaps.map do |swap|
                  if swap[:rated]
                    swap.save_or_make_frth
                  end
                end
              end
            end
            puts ' '
            contract.p = date; contract.save!
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
      warnings: true,
      measure: false,
      force_update: false
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

      puts "Running swapproximate on #{contract} for "+date.strftime("%a, %Y-%m-%d").light_white
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

      base = Cotcube::Bardata.provide contract: contract, interval: :synthetic, force_update: force_update
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
          #    this is important as zero is the focal point or pivot point
          #
          #####################################################################################


          stencil  = Stencil.new( interval: :synthetic, swap_type: swap_type, debug: debug, date: date, contract: contract, warnings: warnings )
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
          # next step is to load currently contracts swap_history and to check
          #    1. which swaps ended yesterday
          #    2. which swaps are confirmed or approached
          #
          ################################################################################

          ################################################################################
          #
          # next step is to detect new swaps a.k.a swapproximation
          #
          ################################################################################


          measuring.call("Beginning of stage 4 (detecting new swaps)")

          measuring.call "DEBUG in swapproximate: detecting within '#{combo}."
          result[combo].swaps = Cotcube::SwapSeeker::Helpers.triangulate(base: result[combo].base, deviation: 2, side: side, debug: debug, contract: contract)
          result[combo].swaps.map do |x|
            x.type     = combo
            x.day      = Days.find_or_create_by(d: date)
            x.contract = Contract.find_or_create_by(s: contract)
            x.r        = x.members.map{|x| x[:i]}.sort.to_json
          end
          measuring.call "DEBUG in swapprocimate: detection for '#{combo}' finished"
          result.delete(combo) if result[combo].swaps.empty? and not keep

        end
      end

      result
    end
  end
end

