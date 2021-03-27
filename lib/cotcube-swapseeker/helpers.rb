# frozen_string_literal: true

module Cotcube
  module SwapSeeker
    module Helpers
      def rad2deg(deg)
        deg * 180 / Math::PI
      end

      def deg2rad(rad)
        rad * Math::PI / 180
      end

      def shear_to_deg(base:, deg:)
        shear_to_rad(base: base, rad: deg2rad(deg))
      end

      def shear_to_rad(base: , rad:)
        tan = Math.tan(rad)
        base.map { |bar|
          # separating lines for easier debugging
          bar[:yy] =
            bar[:y] +
            (bar[:dx].nil? ? bar[:x] : bar[:dx]) * tan
          bar
        }
      end
    end
  end
end

#require_relative 'helpers/array.rb'
#require_relative 'helpers/detect_clusters.rb'
#require_relative 'helpers/fill_x.rb'

module Cotcube
  module SwapSeeker
    module Helpers
      module_function :rad2deg, 
        :deg2rad, 
        :shear_to_deg, 
        :shear_to_rad
    end
  end
end

