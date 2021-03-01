# frozen_string_literal: true

module Cotcube
  module SwapSeeker
    SYMBOL_EXAMPLES = [
      { id: '13874U', symbol: 'ET', ticksize: 0.25, power: 1.25, months: 'HMUZ', bcf: 1.0, reports: 'LF',
        name: 'S&P 500 MICRO' },
      { id: '209747', symbol: 'NM', ticksize: 0.25, power: 0.5,  monhts: 'HMUZ', bcf: 1.0, reports: 'LF',
        name: 'NASDAQ 100 MICRO' }
    ].freeze

    COLORS         = %i[light_red light_yellow light_green red yellow green cyan magenta blue].freeze
    MONTH_COLOURS  = { 'F' => :cyan,  'G' => :green,   'H' => :light_green,
                       'J' => :blue,  'K' => :yellow,  'M' => :light_yellow,
                       'N' => :cyan,  'Q' => :magenta, 'U' => :light_magenta,
                       'V' => :blue,  'X' => :red,     'Z' => :light_red }.freeze

    CHICAGO  = Time.find_zone('America/Chicago')

  end
end
