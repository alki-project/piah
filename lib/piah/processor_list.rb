module Piah
  class ProcessorList
    def initialize(*processors)
      @processors = processors.flatten
    end

    def types
      @types ||= @processors.each_index.zip(@processors.map(&:types)).to_h
    end

    def process(p,args)
      @processors[p].process args
    end
  end
end
