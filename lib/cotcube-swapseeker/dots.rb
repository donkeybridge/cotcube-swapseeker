# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    def dots(contract:,            # the contract to investigate
             symbol: nil, id: nil,
             last: nil,            # if unset the method uses the last available bar as origin
             interval: :synth,     # same as in Bardata, the size of the each bar
             filter:   :full,      # same as in Bardata, the domain of definition of retrieved bars
             swap_type: :full,     # the domain of definition for the swap detection. 
             # :full, :rth, :_24x7_ et al.
             include_holidays: false,
             debug: false,
             measure: false,
             range:  (0..-1),
             timezone: Time.find_zone('America/Chicago'),
             config: init)

      t0 = Time.now if measure
      raise ArgumentError, "Contract length should be 3 (like 'H12') or 5 (like 'ESZ20')" unless contract.is_a? String and [3,5].include? contract.length
      unless range.nil? or 
        (range.is_a? Range and 
           [ Integer, Date, DateTime, ActiveSupport::TimeWithZone ].map {|cl| (range.begin.nil? || range.begin.is_a?(cl)) and 
                                                               (range.end.nil?   || range.end.is_a?(cl)  )        }.reduce(:|) 
        )
        raise ArgumentError, "Range, if given, must be either (Integer..Integer) or (Timelike..Timelike)"
      end

      integer_range = ((range.is_a?(Range)) and ((range.begin.is_a?(Integer)) || range.end.is_a?(Integer)))
      sym = Cotcube::Bardata.get_id_set(symbol: symbol, id: id, contract: contract)
      contract = "#{sym[:symbol]}#{contract}" if contract.size==3
      # retrieve base data for contract dependent on base_type and interval
      # NOTE: this is quite time expensive on big files
      base = Cotcube::Bardata.provide contract: contract,
        interval: interval,
        filter: filter,
        range: (integer_range ? nil : range)
      base = base[range] if integer_range
      puts base.first if debug
      puts base.last if debug
      p (Time.now - t0) if measure
      base.map{|b| b[:datetime] = b[:datetime].to_date} if [:days, :day].include?(interval)
      #base.map{|x| x[:datetime] = timezone.parse(x[:date]) } if [:dailies, :daily].include? interval

      # up to this step the bar data is provided, fitted into it interval (i.e. bar duration and filter for :rth, :full or any custom set
      # the next step now is create a stencil according to the desired swap type (either also :full, or :rth, or some other subsets)
      # and merge those two
      #
      ranges  = Cotcube::Bardata.trading_hours symbol: sym[:symbol], filter: [].include?(swap_type) 

      stencil = stencil( 
                        range: (base.first[:datetime]..base.last[:datetime]),
                        interval: interval,
                        ranges: ranges,
                        swap_type: swap_type,
                        include_holidays: include_holidays,
                        config: config
                       ) 

      p Time.now - t0 if measure
      # press the prototype into the stencil, warning if the prototype contains fields not covered by the stencil
      # NOTE: in the very beginning, i.e. i.zero?, the stencil and the base have the same timestamp and the base has values
      #       later on, it might happen, that
      #           - the stencil has more values (as the swap might run out if busisness hours)
      #           - the base has more values (what should not happen, as it is filtered --- so a warning is printed and data is droppred)

      offset = 0 
      stencil.map{|x| x[:datetime] = timezone.parse(x[:datetime].strftime('%Y-%m-%d'))} if [:daily,:dailies,:synth,:synthetic].include? interval
      base.each_with_index do |_,i|
        puts "BA: #{base[i][:datetime]}" if debug
        # puts  "#{stencil[i+offset][:datetime]} < #{base[i][:datetime]}"
        begin 
          while stencil[i+offset][:datetime] < base[i][:datetime]
            puts "skipping #{stencil[i+offset][:datetime]}".yellow if debug
            offset += 1
          end
        rescue
          # I dont know why but for holidays it fails
          puts "WARNING: Holiday found. skipping!".light_yellow
          return { upper: [], lower: [] }
        end
        if stencil[i+offset][:datetime] > base[i][:datetime]
          puts "skipping #{base[i]}".light_yellow if debug
          offset -= 1
          next
        end
        j = i + offset
        puts "#{i}\t#{offset}" if debug
        puts "ST: #{stencil[j][:datetime]}" if debug
        stencil[j] = stencil[j].merge(base[i])
        puts "->: #{stencil[j]}\n\n" if debug
      end
      p Time.now - t0 if measure

      # and remove all unneeded fields afterwards
      stencil.select!{|x| not x[:high].nil? }

      { 
        upper: stencil.map{|x| x[:y] = x[:high] - stencil.last[:high]; [:open, :close, :volume, :oi, :contract, :type].each{|z| x.delete(z)}; x.dup},
        lower: stencil.map{|x| x[:y] = stencil.last[:low]  -  x[:low]; x    }
      }
    end

  end
end

