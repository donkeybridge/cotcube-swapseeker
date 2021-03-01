Mongoid.load!("./mongoid.yml",:development)
Mongoid.logger.level       = Logger::WARN
Mongo::Logger.logger.level = Logger::WARN

%i[ stencil day asset contract member swap].each do |model|
  require_relative "#{__dir__}/models/#{model}" 
end

Mongoid::Tasks::Database.create_indexes

