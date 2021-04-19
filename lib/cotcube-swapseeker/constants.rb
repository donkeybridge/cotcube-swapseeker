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

    MONTHS         = { 'F' => 1,  'G' =>  2, 'H' =>  3,
                       'J' => 4,  'K' =>  5, 'M' =>  6,
                       'N' => 7,  'Q' =>  8, 'U' =>  9,
                       'V' => 10, 'X' => 11, 'Z' => 12,
                        1 => 'F',  2 => 'G',  3 => 'H',
                        4 => 'J',  5 => 'K',  6 => 'M',
                        7 => 'N',  8 => 'Q',  9 => 'U',
                       10 => 'V', 11 => 'X', 12 => 'Z' }.freeze


    CHICAGO  = Time.find_zone('America/Chicago')

  end
end
