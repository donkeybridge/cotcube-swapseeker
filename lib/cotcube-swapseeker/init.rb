# frozen_string_literal: true

module Cotcube
  module SwapSeeker


    def symbols(config: init, type: nil, symbol: nil)
      if config[:symbols_file].nil?
        SYMBOL_EXAMPLES
      else
        CSV
          .read(config[:symbols_file], headers: %i{ id symbol ticksize power months type bcf reports name})
          .map{|row| row.to_h }
          .map{|row| [ :ticksize, :power, :bcf ].each {|z| row[z] = row[z].to_f}; row }
          .reject{|row| row[:id].nil? }
          .tap{|all| all.select!{|x| x[:type] == type} unless type.nil? }
          .tap { |all| all.select! { |x| x[:symbol] == symbol } unless symbol.nil? }
      end
    end

    def config_prefix
      os       = Gem::Platform.local.os
      case os
      when 'linux'
        ''
      when 'freebsd'
        '/usr/local'
      else
        raise RuntimeError, 'unknown architecture'
      end
    end

    def config_path
      config_prefix + '/etc/cotcube'
    end

    def init(config_file_name: 'swapseeker.yml', debug: false)
      name = 'swapseeker'
      config_file = config_path + "/#{config_file_name}"

      if File.exist?(config_file)
        config      = YAML.load(File.read config_file).transform_keys(&:to_sym)
      else
        config      = {} 
      end

      defaults = { 
        data_path: config_prefix + '/var/cotcube/' + name,
      }


      config = defaults.merge(config)
      puts "CONFIG is '#{config}'" if debug


      # part 2 of init process: Prepare directories

      save_create_directory = lambda do |directory_name|
        unless Dir.exist?(directory_name)
          begin
            `mkdir -p #{directory_name}`
            unless $?.exitstatus.zero?
              puts "Missing permissions to create or access '#{directory_name}', please clarify manually"
              exit 1 unless defined?(IRB)
            end
          rescue 
            puts "Missing permissions to create or access '#{directory_name}', please clarify manually"
            exit 1 unless defined?(IRB)
          end
        end
      end
      symbols(config: config).map{|x| x[:symbol]}.each do |sym|
        dir = "#{config[:data_path]}/#{sym}"
        save_create_directory.call(dir)
      end
      config
    end
  end
end

