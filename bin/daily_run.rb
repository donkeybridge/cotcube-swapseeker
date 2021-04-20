#!/usr/bin/env ruby

require_relative '../lib/cotcube-swapseeker'

include Cotcube::SwapSeeker
swapproximate_daily( processes: 1)
