module Cotcube
  module SwapSeeker
    module Helpers
      def triangulate(
          contract: nil,        # contract actually isnt needed to triangulation, but allows much more convenient output
          side:,                # :upper or :lower
          base:,                # a Stencil with injected base
          range: (0..-1),       # range is relative to base.
          max: 90,              # the range which to scan for swaps goes from deg 0 to max
          debug: false,
          format: '% 5.2f',
          min_members: 3,       # this param should not be changed manually, it is used for the guess operation
          allow_sub: true,      # this param determines whether guess can be called or not
          deviation: 2)

        raise ArgumentError, "'0 < max < 90, but got '#{max}'" unless max.is_a? Numeric and 0 < max and max <= 90
        raise ArgumentError, 'need :side either :upper or :lower for dots' unless [:upper, :lower].include? side

        # init some helpers
        high = side == :upper
        first = base.find{|x|  not x[:high].nil? }
        zero = base.select{|x| x[:x].zero? }
        raise ArgumentError, "Inappropriate base, it should contain ONE :x.zero, but contains #{zero.size}." unless zero.size==1
        zero = zero.first

        # prepare nase (i.e. dupe the original, create proper :y, and reject unneeded items
        base = base.
          map { |x|
            y = x.dup
            y[:y] = (high ?
                     (y[:high] - zero[:high]).round(8) :
                     (zero[:low] - y[:low]).round(8)
                    ) unless y[:high].nil?
            #[ :open, :close, :type ].map{|z| y.delete(z) }
            y
          }.
          reject{|b| b[:datetime] < first[:datetime] or b[:x] < 0 or b[:y].nil?}[range]

        contract ||= base.first[:contract]
        sym = Cotcube::Bardata.get_id_set(contract: contract)

        unless range == (0..-1)
          puts "adjusting range to '#{range}'".light_yellow if debug
          offset_x = base.last[:x]
          offset_y = base.last[:y]
          base.map!{|b| b[:x] -= offset_x; b[:y] -= offset_y  ; b}
        end

        ticksize = sym[:ticksize]  / sym[:bcf] # need to adjust, as we are working on barchart data, not on exchange data !!

        # simplifying output with a lambda
        present = lambda {|z| "#{z[:datetime].strftime("%a, %Y-%m-%d %H:%M")
                         }  x: #{format '%-4d', z[:x]
                         } dx: #{format '%-4d', (z[:dx].nil? ? z[:x] : z[:dx]) 
                            }, #{high ? "high" : "low"
                            }: #{format format, z[high ? :high : :low]
                         }, i: #{(format '%4d', z[:i]) unless z[:i].nil?}" 
        }

        # another lambda to find the x-fit, for each member where it is zero.
        finalize = lambda do |res|
          res.each do |r|
            r[:members].each  do |m|
              next if m[:yy].nil? or m[:yy].zero?

              diff = (m[:x] - m[:dx]).abs / 2.0
              m[:dx] = m[:x] + diff
              # it employs another binary-search
              while m[:yy].round(8) != 0
                m[:yy] = shear_to_deg(deg: r[:deg], base: [ m ] ).first[:yy]
                diff /= 2.0
                if m[:yy] > 0
                  m[:dx] += diff
                else
                  m[:dx] -= diff
                end
              end
              m[:yy] = m[:yy].abs.round(8)
            end # r[:members]

            r[:members].each {|x| puts "finalizing #{x}" } if debug

            if allow_sub
              puts "going sub".light_yellow if debug
              sub_range = (r[:members][0][:i]..r[:members][-2][:i])
              sub_x     =  r[:members][-2][:x]
              sub_y     =  r[:members][-2][:y]
              sub_base  =  base.map{|x| z = x.dup; z[:dx]=nil; z}

              sub = triangulate(base: sub_base,
                                contract: contract,
                                range: sub_range,
                                side: side,
                                min_members: 2, 
                                allow_sub: not(allow_sub), 
                                debug: debug).first
              r[:sub] = sub
	      r[:guess] = lambda {|x| 
                return -1 if sub.nil? or sub[:slope].nil?
		if side==:upper
		  r[:members].last[:high] + (x-sub_x) * sub[:slope] + sub_y
		elsif side == :lower
		  r[:members].last[:low]  -  x *        sub[:slope] + sub_y
		else
		  "ERROR: NO actual withoud :side (lambda in detect_slope)!".light_red
		end

	      }
		puts "offsets x:#{sub_x}\ty: #{sub_y}".light_green if debug
	    end  # if allow_sub

	  end    # res
	end      # lambda


	# a third lambda, the actual 'function' to retrieve the slope
	get_slope = lambda do |b|
	  if debug
	    puts "SETTING BASE: ".light_green
	    puts "Last:\t#{present.call  b.last}"
	    puts "First:\t#{present.call b.first}"
	  end
	  members = [ b.last[:i] ]
	  loop do
	    current_slope   = detect_slope(base: b, ticksize: ticksize, format: format, side: side, debug: debug)
	    current_members = current_slope[:members]
	      .map{|dot| dot[:i]}
	    new_members = current_members - members
	    puts "New members: #{new_members} as of #{current_members} - #{members}" if debug
	    # the return condition is if no new members are found in slope
	    # except lowest members are neighbours, what causes a re-run
	    if new_members.empty? 
	      mem_sorted=members.sort
	      if mem_sorted[1] == mem_sorted[0] + 1
                b2 = b[mem_sorted[1]..mem_sorted[-1]].map{|x| x.dup; x[:dx] = nil; x}
                alternative_slope = get_slope.call(b2)
		alternative = alternative_slope[:members].map{|bar| bar[:i]}
		if (mem_sorted[1..-1] - alternative).empty?
		  current_slope = alternative_slope
		  members = alternative
		end
	      end
              if min_members >= 3 and members.size >= 3
                current_slope[:raw]    = members.map{|x| x.abs }.sort
                current_slope[:length] = current_slope[:raw][-1] - current_slope[:raw][0]
                current_slope[:rating] = current_slope[:raw][1..-2].map{|dot| [ dot - current_slope[:raw][0], current_slope[:raw][-1] - dot].min }.max
                current_slope[:rated]  = (
                                          current_slope[:rating] > 3 or 
                                          current_slope[:raw].size >  4 
                                         ) 
              end
              members.sort_by{|i| -i}.each do |x|
                puts "#{range}\t#{present.call(b[x])}" if debug
                # current_slope[:members] = []
                current_slope[:members] << b[x] unless current_slope[:members].map{|x| x[:datetime]}.include? b[x][:datetime]
                current_slope[:members].sort_by!{|x| x[:datetime]}
              end
              return current_slope

            end
            new_members.each do |mem|
              current_deviation = (0.1 * b[mem][:x])
              current_deviation =  1                  if current_deviation < 1
              current_deviation =  deviation          if current_deviation > deviation
              b[mem][:dx] = b[mem][:x] + current_deviation
            end
            members += new_members
          end
        end # of lambda




        base.each_index.map{|i| base[i][:i] = -base.size + i } 
        old_base = base.dup

        current_range = (0..-1)
        current_slope = { members: [] }
        current_base = base[current_range]
        current_results = [ ]
        while current_base.size >= 5
          while current_base.size >= 5 and current_slope[:members].size < min_members
            puts current_range.to_s.light_yellow if debug
            current_slope = get_slope.call(current_base)
            next_i = current_slope[:members][-2]
            current_range = ((next_i.nil? ? -2 : next_i[:i])+1..-1)
            current_base = base[current_range]
            STDIN.gets if debug
          end
          puts "#{current_slope}" if debug# is a swap
          current_results << current_slope if current_slope 
          current_slope = { members: [] }
        end
        # current_results.select!{|x| x[:members].size >= min_members }
        current_results.select!{|x|  x[:members][0..-2].size > min_members or x[:members][0..-2].one_by_one{|a,b| (a[:x] - b[:x]).abs > 1 }.reduce(:|)}
        finalize.call(current_results)
        current_results
      end
    end
  end
end
