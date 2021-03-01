module Cotcube
  module SwapSeeker
    class Swap

      include Mongoid::Document
      embedded_in :swap
    end
  end
end
