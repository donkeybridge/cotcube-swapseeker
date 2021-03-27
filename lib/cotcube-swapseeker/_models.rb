Mongoid.load!("./mongoid.yml",:development)
Mongoid.logger.level       = Logger::WARN
Mongo::Logger.logger.level = Logger::WARN

# non-DB models

%i[stencil].each do |model|
  require_relative "#{__dir__}/models/#{model}"
end

# DB models

# Day has many swaps
# Contract has many swaps
#      belongs to asset
# Swap belongs to day and contract
#      embeds members, line and guess

%i[bar line day asset contract member swap].each do |model|
  require_relative "#{__dir__}/models/#{model}" 
end

Mongoid::Tasks::Database.create_indexes

