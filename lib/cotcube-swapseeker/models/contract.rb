module Cotcube
  module SwapSeeker
    class Contract

      include Mongoid::Document
      has_many :swaps, class_name: 'Swap', inverse_of: :contract
      belongs_to :asset, class_name: 'Asset', inverse_of: :contract
      # has_many :signals   # talking about COT signals here

      field :s, as: :sign, type: String # e.g. CLH22
      field :m, as: :first_ml, type: Date
      field :f, as: :first, type: Date
      field :l, as: :last, type: Date
      field :p, as: :last_processed, type: Date

      validates_presence_of :asset
      validates_uniqueness_of :s
      validates_presence_of :s, :m

      before_save do |document|
        if document.first_ml.nil?
          document.projected_first_ml
        end
      end

      %i[ sym type ticksize power months name].each {|m|
        define_method(m) { self.asset.send(m) }
      }

      def to_tick(x); (x / ticksize).round * ticksize;              end

      def self.method_missing(method, *args, &block)
        m = method.to_s.upcase
        super unless [2,3,5].include? m.size
        contracts = Contracts.where( :s => /#{m}/)
        super if contracts.count == 0
        contracts.size==1 ? contracts.first : contracts
      end

      def self.check_all_available(rewrite: false, debug: false)
        path = "#{init[:data_path]}/../bardata/daily"
        Dir["#{path}/*"].each do |asset_path|
          asset_string = asset_path.split('/').last
          next if asset_string.length > 2
          puts "checking #{asset_string}"
          asset = Asset.send(asset_string.to_sym)
          # check for contracts that are not yet in DB
          Dir["#{asset_path}/*.csv"].each do |contract_file|
            part     = contract_file.split('/').last[0..2]
            month    = part[0]
            next if part == 'con' or not (asset.months.include? month)

            contract_string = "#{asset_string}#{part}"
            contract = Contract.find_or_create_by(s: contract_string)
            if rewrite
              contract.first = nil
              contract.last  = nil
            end
            next if not contract.last.nil?

            puts "digging into #{contract.inspect}" if debug
            if contract.first.nil?
              contract.first = contract.dailies.first[:datetime].to_date
              puts "Initialize #{contract_string} starting at #{contract.first}."
            end
            if contract.last.nil? and contract.dailies(keep_last: true).last[:close] == 0.0
              contract.last  = contract.dailies.last[:datetime].to_date
              puts "    Closed #{contract_string} ending   at #{contract.last}.".red
            end
            contract.asset = asset if contract.asset.nil?
            contract.projected_first_ml
            contract.save!
          end
        end
      end

      # active contracts are those that are not closed yet and will end within the next 366 days
      # (resp. whats promised by the contracts name)
      def self.active(days: 366)
        target = Date.today + days
        month  = target.month
        year   = target.year % 100
        valid  = (MONTHS.keys.map{|x| ["#{x}#{year-2}", "#{x}#{year-1}"] } + MONTHS.keys[0...month].map{|x| "#{x}#{year}" } ).flatten
        Contracts.where(last: nil).select{|x| valid.include? x.s[-3..-1] }.sort_by{|x| x.s[0..1]}.sort_by{|x| x.s[2]}.sort_by{|x| x.s[-2..-1] }
      end

      # considerable contracts are those, that are active and whose
      # first_ml has either passed or arrives within the next 90 days
      #
      # As this is a consuming process, it should be done as part of an EoX process
      def self.considerable(force: false, days: 90)
        file = "#{Cotcube::SwapSeeker.init[:data_path]}/considerable_contracts.csv"
        if force or (File.mtime(file).to_i - Time.now.to_i).abs > 1.week
          considerable_contracts = Contracts.active.select{|contract| contract.projected_first_ml - days.days < Date.today rescue false }.map{|x| x.s}
          CSV.open(file, 'w'){|csv| csv << considerable_contracts }
        end
        (considerable_contracts ||= CSV.read(file).first).map{|x| Contract.send(x.to_s)}
      end

      def self.with_swaps
        Contracts.where(:swaps.nin => [nil])
      end

      def inspect
        "#<Cotcube::SwapSeeker::Contract s(sign): \"#{self.s
           }\", f(first): \"#{   self.f.nil? ? 'ERROR   ' : self.f.strftime('%y-%m-%d')
           }\", m(first_ml): \"#{self.m.nil? ? 'UNINITIA' : self.m.strftime('%y-%m-%d')
           }\", l(last): \"#{    self.l.nil? ? 'OPEN    ' : self.l.strftime('%y-%m-%d')
           }\", p: \"#{          self.p.nil? ? 'UNINITIA' : self.p.strftime('%y-%m-%d')
           }\" >"
      end

      def synthetics
        @synthetics ||= Cotcube::Bardata.provide contract: sign, interval: :synthetic
      end

      def dailies(keep_last: false)
        @dailies    ||= Cotcube::Bardata.provide_daily contract: sign, keep_last: true, config: Cotcube::Bardata.init
        if keep_last
          @dailies
        elsif @dailies.last[:close].zero?
          @dailies[0...-1]
        else
          @dailies
        end
      end

      def projected_first_ml
        return self.first_ml unless self.first_ml.nil?
        const =  "SWAPSEEKER_YDAYS_#{self.asset.symbol}"
        Object.const_set const, Cotcube::Bardata.continuous_table(symbol: self.asset.symbol, debug: true, short: false, silent: true) unless Object.const_defined?(const)
        yday = Object.const_get(const).select{|x| x[:month] == self.s[2]}.first[:first_ml] rescue nil
        return self.first_ml = Date.new(2100) if yday.nil?
        year = self.s[-2..-1]
        self.first_ml = DateTime.strptime("#{year} #{yday}", '%y %j')
        self.first_ml -= 1.year unless self.validate_first_ml
        self.first_ml
      end

      def validate_first_ml
        # the expiration month based on sign
        vml = "20#{self.s[-2..-1]}#{format '%02d', MONTHS[self.s[2]]}"
        # the first_ml as string
        return true if self.m.nil?
        dml = self.m.strftime('%Y%m')
        return true if dml == '210001'
        vml > dml
      end

      def set_p(p=nil)
        puts "WARNING: Contract#set_p is buggy.".light_red
        unless p.nil?
          self.p = p
        else
          self.p = (self.swaps.count.zero? ? nil : self.swaps.sort_by{|sw| sw.day.d }.last.day.d)
        end
        self.save!
      end

    end

    Contracts = Contract
  end
end
