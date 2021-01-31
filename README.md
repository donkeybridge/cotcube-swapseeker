## SwapSeeker

This gem integrates the feature of detecting slopes of swaplines into the cotcube suite, which are--in a conventional view--a subset of trendlines within a charting picture. And indeed a swapline is basically not anymore than a trendline which has at least 3 tangential members. Based on the observation, that 3 or more members exist, a linear function is computed and furthermore used to appraise a distance to the current market and to generate a signal on crossing. 

The assumption here is, that there are financial service providers, that offer IR swaps to mitigate the variable interest rate risk (which arises when a big entity needs to enlarge or reduce its huge market position and does not know, _when_ it will meet a partner for the deal) to a fixed interest rate risk (like betting, that the opposite side of the deal will appear sooner, not later). Still--we don't know when the _whales_ enter and leave the market, but as long they are there, they act as bounderies for price development. 

Let's take a tiny peek from the sellers perspective: For as long as a selling swap is in the market, every other seller has to offer cheaper to find a counter party earlier than the swap dealer--what is embraced by buyers, because prices go down on selling pressure. Finally when buying pressure rises and all other singular or spontaneous sellers have settled their deals, the price returns to the swap line and remains there until new selling pressure arises--and finally when the swap dealer has sold its stock, the price may rise beyond this _virtual_ line. 

There are some phenomena remaining unexplained here. Please just accept for now that we are not dealing with 'trend channels', just with their upper part on selling swaps and lower parts on buying swaps. The detection stops at an even level, what would be the same as e.g. sending a SELL order of 5000 contracts of lumber at a fixed price--waiting until everything is sold regardless of surrounding events or price development. 

Part of this code is a legacy of the gem Bitangent--but rebuild to include the features of the Cotcube::Helpers.

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/cotcube-swapseeker.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
