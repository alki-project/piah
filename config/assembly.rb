Alki do
  set :processors do
    []
  end

  service :root_processor do
    require 'piah/processor_list'
    Piah::ProcessorList.new(processors.to_a)
  end

  factory :process do
    require 'piah/config_processor'
    Piah::ConfigProcessor.new(root_processor).method(:process)
  end
end
