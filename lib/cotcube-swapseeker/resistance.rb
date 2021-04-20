# frozen_string_literal: true

module Cotcube
  module SwapSeeker

    def check_high_low(symbol: nil, contract: nil, last_n: 60)
      raise ArgumentError, "Need either :symbol or :contract as parameter" if symbol.nil? and contract.nil?
      contract ||= Cotcube::Bardata.continuous_table symbol: symbol
      sym  = Cotcube::Bardata.get_id_set(contract: contract)
      [:full, :rth].each do |filter| 
        base = Cotcube::Bardata.provide contract: contract, filter: filter
        base.one_by_one(:hdiff){|a,b| ((a[:high] - b[:high]).abs / sym[:ticksize]).round }
        base.one_by_one(:ldiff){|a,b| ((a[:low ] - b[:low ]).abs / sym[:ticksize]).round }
        base.shift
        puts "Check high for #{contract}\t#{filter}:".light_yellow
        Cotcube::Bardata.range_matrix(base: base, days_only: true, last_n: last_n, print: true) {|x| x[:hdiff]}
        puts "Check low for #{contract}\t#{filter}::".light_yellow
        Cotcube::Bardata.range_matrix(base: base, days_only: true, last_n: last_n, print: true) {|x| x[:ldiff]}
      end
    end



    def resistance(base:, dev: 5)
      sym = Cotcube::Bardata.get_id_set(contract: base.last[:contract])
      ticksize = sym[:ticksize]
      last = base.last.dup
      res  = [ last ]
      use_base = base.select{|x| x[:high] + dev * ticksize >= last[:high] }
      diff = 2
      while use_base.size >= diff
        high_dev  = ((use_base[-1][:high] - use_base[-diff][:high]).abs / ticksize).round
        if high_dev <= dev
          diff += 1
          res << use_base[-diff]
        else
          if diff > 2
            puts "#{diff}\t#{res.first[:datetime]}\t#{res.map{|x| x[:high]}.max}"
            res.each {|x| p x} 
          end
          diff = 2
          use_base.pop
          last = use_base.last.dup
          res  = [ last ]
          use_base.select!{|x| x[:high] >= last[:high]  - dev * ticksize}
        end
      end
      if diff > 2
        puts "#{diff}\t#{res.first[:datetime]}\t#{res.map{|x| x[:high]}.max}"
        res.each {|x| p x}
      end




    end

  end
end
