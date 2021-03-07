module Cotcube
  module SwapSeeker
    module Helpers
      # NOTE: There is no need for :side, as the :base is expected to be positive (i.e. lower has to be inverted)
      def detect_slope(base:, max: 90, debug: false, format: '% 5.2f', calculus: false, ticksize: nil, side: nil, max_dev: 200)
        raise ArgumentError, "'0 < max < 90, but got '#{max}'" unless max.is_a? Numeric and 0 < max and max <= 90
        #
        # aiming for a shearing angle, all but those in a line below the abscissa
        #
        # doing a binary search starting at part = 45 degrees
        # on each iteration,
        #   part is halved and added or substracted based on current success
        #   if more than the mandatory result is found, all negative results are removed and degrees are increased by part
        #
        # --- sadly, math.atan is not working as expected
        # --- finally, :deg is adjusted to the actual slope with a Math.atan operation
        #
        raise ArgumentError, 'detect_slope needs param Array :base' unless base.is_a? Array
        old_base = base.dup.select{|b| b[:x] >= 0 and not b[:y].nil? }


        old_base.each {|x| p x} if old_base.size < 50 and debug
        deg ||= -max / 2.0 
        new_base = shear_to_deg(base: old_base, deg: deg).select { |d| d[:yy] >= 0 }
        puts "Iterating slope:\t#{format '% 7.5f',deg
                           }\t\t#{new_base.size
                           } || #{new_base.values_at(*[0]).map{|f| "'#{f[:x]
                                                                    } | #{format format,f[:y]
                                                                    } | #{format format,f[:yy]}'"}.join(" || ") }" if debug
        part = deg.abs
        #
        # the loop, that runs until either
        #   - only two points are left on the slope
        #   - the slope has even angle
        #   - several points are on the slope in quite a good approximation ('round(8)')
        #
        until deg.round(8).zero? ||
            ((new_base.size >= 2) && (new_base.map { |f| f[:yy].round(8).zero? }.uniq.size == 1))
          part /= 2.0
          # if new_base.size == 2 and not predicted
          #   deg = rad2deg(Math.atan((new_base[0][:yy] - new_base[0][:y]) / new_base[0][:x])) unless new_base[0][:yy].zero?
          #
          #   puts "Predicting #{deg.round(8)} as result."
          #   predicted = true
          # end
          if new_base.size == 1 # the graph was sheared too far, reuse old_base
            deg = deg + part
          else
            # the graph was sheared too short, continue with new base
            deg = deg - part
            old_base = new_base.dup
          end
          new_base = shear_to_deg(base: old_base, deg: deg).select { |d| d[:yy] >= 0 }
          new_base.last[:dx] = 0.0 
          #puts "Iterating slope:\t#{format '% 8.5f',deg
          #                      }\t#{new_base.size
          #                    } || #{new_base.values_at(*[0]).map{|f| "'#{f[:x]
          #                                                          } | #{format format,f[:y]
          #                                                          } | #{format format,f[:yy]}'"}.join(" || ") }" if debug
        end
        # define the approximited result as (also) 0.0
        new_base.each{|x| x[:yy] = 0.0}
        if debug
          puts "RESULT: "
          new_base.each {|f| puts "\t#{f}" }
          puts "RESULT #{deg} #{deg2rad(deg)}"
        end
        if deg.round(8).zero?
          return { deg: 0,  members: new_base.map { |x| xx = x.dup; %i[y yy].map { |z|  xx.delete(z) }; xx } }
        end
        # the promised atan operation the find the perfect slope angle
        #
        # the atan actually is not needed, as the result of the binary search should be exact enough
        atan = nil # rad2deg(Math.atan((new_base[0][:yy] - new_base[0][:y]) / new_base[0][:x])) unless new_base[0][:yy].zero?

        # y = m x + n --> n = y - mx
        slope     = (new_base.first[:y] - new_base.last[:y]) / (
                        (new_base.first[:dx].nil? ? new_base.first[:x] : new_base.first[:dx]).to_f - 
                        (new_base. last[:dx].nil? ? new_base. last[:x] : new_base. last[:dx]).to_f 
                      )
        # TODO: change or add, so that calculus returns actual expectation value for future dates as well
        function  = lambda {|x| x * slope }
        actual    = lambda {|x| 
          if side==:upper
            new_base.last[:high] + x * slope 
          elsif side == :lower
            new_base.last[:low] - x * slope
          else
            "ERROR: NO actual withoud :side (lambda in detect_slope)!".light_red
          end
        }
        calculus_lambda  = lambda do  |dev: max_dev, members: []|
          upper = side == :upper
          clusters = [] 
          unclustered  = [] 
          base.map do |d| 
            # what would y be if I'd call the function
            d[:sy] = function.call(d[:dx].nil? ? d[:x] : d[:dx])
            # what is the distance to actual y in ticks
            d[:dy] = d[:sy] - d[:y]
            # same in ticks
            d[:t]  = d[:dy] / ticksize if ticksize.is_a?(Float) and not ticksize.zero?
          end
          puts '-'*60
          puts " "
          tick_range = Cotcube::Helpers.simple_series_stats(prefix: 'tick_range', base: base, ind: :range, dim: 0.01){|x| (x[:high] - x[:low]) / ticksize }
          tick_dist  = Cotcube::Helpers.simple_series_stats(prefix: 'tick_dist to slope', base: base, ind: :t, dim: 0.01)
          puts " "

          sorted = base.select{|d| d[:t] < tick_range[:median]}.sort_by{|d| d[:dy]}
          # lazy clustering ... 
          # predefined sind zwei cluster: [ sorted[0] ] und [ sorted[1] ]
          clusters = [ [ sorted[1] ], [ sorted[0] ] ]
          # sorted wird iteriert, jedes element wird
          #   1. ignoriert, wenn es teil eines clusters ist
          #   2. zu einem cluster sortiert, wenn es zu irgendeinem element im cluster weniger als dx <= 5 entfernt ist
          #   3. bildet mit einem element der unclustered liste ein neues cluster, wenn weniger als dx <= 5
          #   ELSE auf die unclustered liste gesetzt
          # danach wird das gleiche nochmal mit der unclustered liste gemacht
          # danach werden die cluster durchgegangen, ob ggfs. cluster gemerged werden können
          max_dist = 3
          sorted.take(25).each do |el|
            # skip if current element is already cluster member
            next if clusters.map{|cl| cl.include?(el) }.reduce(:|)

            # join current element to cluster if it is near a cluster member
            # and leave loop if successful
            clusters.map{|cl| cl << el if cl.map{|clel| (clel[:x] - el[:x]).abs <= max_dist}.reduce(:|)} 
            next if clusters.map{|cl| cl.include?(el) }.reduce(:|)

            # consider el to form a new cluster with any element listed in unclustered
            new_cluster = [ el ] 
            unclustered.map do |clel| 
              if (clel[:x] - el[:x]).abs <= max_dist
                new_cluster << clel
                unclustered.delete(clel)
              end
            end
            clusters << new_cluster if new_cluster.size > 1
            next if new_cluster.size > 1
            # add el to unclustered if none applies
            unclustered << el
          end
          unclustered.sort_by{|d| d[:dy]}.each {|el| clusters << [ el ] }
          # check if there are only 2 clusters that also share elements
          # if clusters.size == 2 and clusters.first.map{|el0| clusters.last.map{|el1| (el0-el1).abs < max_dist}.reduce(:|)}.reduce(:|)
          #   clusters = [ clusters.first + clusters.last ]
          #   puts "WARNING: seems to be empty result".light_yellow
          # end
          # MERGE clusters that have any neighbouring elements
          broken = true
          clusters.size.times do 
            break unless broken
            broken = false
            clusters.each_with_index do |cl0, i0|
              clusters.each_with_index do |cl1, i1|
                next if i0 >= i1
                if cl0.map{|el0| cl1.map{|el1| (el0[:x]-el1[:x]).abs < max_dist}.reduce(:|)}.reduce(:|)
                  clusters[i0] += clusters[i1]
                  clusters[i1] = nil
                  clusters.compact!
                  broken = true
                  break
                end
              end
              break if broken
            end
          end

          clusters.map{|cl| cl.sort_by!{|d| d[:x]}.uniq! } 
          clusters.sort_by{|cl| cl.first[:x].abs}.each_with_index do |cl, i|
            cl.each_with_index {|d,j| 
              # mark members
              d[:member]=true if (members.include? d[:x])
              # write datetime in specific colour per cluster
              puts "#{d[:datetime]}  ".colorize(COLORS[i]) + 
              # the location on x-axis
                   "#{format('%4d', d[:x])  }  ".colorize(:light_white) + 
              # if given, show additional high for upper resp. low for lower slopes if side was given
                   (side.nil? ? "" : "#{ format '%12s', "#{format(format, d[side==:upper ? :high : :low])}" }")  +
                   (side.nil? ? "" : "#{ format '%12s', "#{format(format, actual.call(d[:dx].nil? ? d[:x] : d[:dx]))}"}") +
                   "    #{format('% 5.2f', d[:t])}".colorize(d[:member].nil? ? :white : :light_yellow)  + 
                   "\t#{d[:member].nil? ? "" : "#{format '%4.3f', (d[:dx] - d[:x])}" }" unless d[:t] > tick_range[:median]
            } 
          end
        end 
        calculus_lambda.call if calculus

        # the result
        # puts "got #{deg.round(8)} as result"
        { error: '', 
          deg:       deg, 
          atan:      atan,
          slope:     slope,
          function:  function,
          actual:    actual,
          calculus:  calculus_lambda,
          members:   new_base.map { |x| x.dup }
        }
      end
    end
  end
end
