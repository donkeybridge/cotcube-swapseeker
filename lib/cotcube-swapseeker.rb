# frozen_string_literal: true
#

module Kernel
  alias deep_freeze freeze
  alias deep_frozen? frozen?
end

module Enumerable
  def deep_freeze
    if !@deep_frozen
      each(&:deep_freeze)
      @deep_frozen = true
    end
    freeze
  end

  def deep_frozen?
    !!@deep_frozen
  end
end

#

require 'active_support'
require 'active_support/core_ext/time'
require 'active_support/core_ext/numeric'
require 'colorize'
require 'httparty'
require 'date' unless defined?(DateTime)
require 'csv'  unless defined?(CSV)
require 'yaml' unless defined?(YAML)
require 'mongoid' unless defined?(Mongoid)
require 'cotcube-helpers'
require 'cotcube-bardata'



require_relative 'cotcube-swapseeker/constants'
require_relative 'cotcube-swapseeker/init'
require_relative 'cotcube-swapseeker/slope'
require_relative 'cotcube-swapseeker/helpers'
require_relative 'cotcube-swapseeker/detect_slope.rb'
require_relative 'cotcube-swapseeker/triangulate.rb'
require_relative 'cotcube-swapseeker/swapproximate'
require_relative 'cotcube-swapseeker/_models'



module Cotcube
  module SwapSeeker
    include Helpers

    module_function :init, # checks whether environment is prepared and returns the config hash
      :config_path,        # provides the path of configuration directory
      :config_prefix,      # provides the prefix of the configuration directory according to OS-specific FSH
      #:stencil,            # the stecil that merges with the base to eventually provide dots
# deprecated      #:dots,               # consisting of :upper and :lower, dots are the normalized series to start shearing
      :triangulate,
      :detect_slope,
      :swapproximate_eod,
      :swapproximate_run,
      :symbols
    
    # please not that module_functions of source provided in private files must be published there
  end
end

