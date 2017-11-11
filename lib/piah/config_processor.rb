module Piah
  class ConfigMergeError < StandardError
    def initialize(a,b)
      super "Failed to merge config values #{a.pretty_print_inspect}\n  and\n#{b.pretty_print_inspect}"
    end
  end

  class ConfigProcessorResultError < StandardError
    def initialize(v)
      super "Config processors must return a Hash or an Array of Hashes, got #{v.inspect}"
    end
  end

  class ConfigProcessor
    def initialize(processor)
      @processor = processor
    end

    # Basic idea is that we have our list of config processors, along with the config types
    # each one accepts. The list becomes our initial "chain", which is a particular ordering
    # of the processors. We then run through the chain, providing each processor with the
    # config types it wants, and adding it's outputs to the set of config types. The result
    # is then a hash of all unhandled config types.
    #
    # If, when processing the chain, a processor (A) outputs a config type that has already been
    # processed by an earlier (in the chain) processor (B), we abort and rearrange the chain so that
    # the A processor will run before the B processor, and then execute the new chain.
    # This repeats until we get all the way through the chain without encountering processors out
    # of order.
    def process(config)
      types = @processor.types
      chain = types.keys.map{|p| [p,{}] }
      result = nil
      config = copy(config)
      until result
        result = process_chain(types,chain,copy(config))
        if result.is_a?(Set)
          # Rearrange chain
          move = chain.size.times.select do |i|
            types[chain[i][0]].to_set.intersect? result
          end
          move.each do |i|
            chain.push [chain[i][0],{}]
            chain[i] = nil
          end
          chain.compact!
          result = nil
        end
      end
      result
    end

    private

    # Returns final output or a Set of keys that have been generated
    # after we've already processed them (requiring re-ordering)
    def process_chain(types,chain,input)
      output = input.dup
      seen = Set.new
      chain.each do |(p,cache)|
        args = input.select{|k| types[p].include?(k) }
        args.keys.each {|k| output.delete k }

        unless cache[:result]
          result = @processor.process(p, copy(args))
          if result.is_a? Array
            cache[:result] = result.inject({}) do |r,c|
              merge(r,copy(c))
            end
          else
            unless result.is_a? Hash
              raise Piah::ConfigProcessorResultError.new result
            end
            cache[:result] = copy(result)
          end
          unless cache[:result].keys.all?{|k| k && k.size > 0}
            raise Piah::ConfigProcessorResultError.new cache[:result]
          end
        end
        keys = cache[:result].keys.to_set
        out_of_order = seen & keys
        # If chain is out of order, abort
        return out_of_order unless out_of_order.empty?

        seen.merge types[p]
        begin
          merge(output,copy(cache[:result]))
        rescue => e
          raise ConfigMergeError.new(output,cache[:result])
        end
        cache[:result].each_key {|k| input[k] = output[k] unless input.key? k }
      end
      output
    end

    def merge(a,b)
      if a.is_a?(Hash) && b.is_a?(Hash)
        a.merge!(b) do |key,av,bv|
          merge av, bv
        end
      elsif a.is_a?(Array) && b.is_a?(Array)
        a.push *b.reject{|e| a.include?(b)}
      elsif a.is_a?(Proc) && b.is_a?(Proc)
        b
      elsif a != b
        raise ConfigMergeError.new(a,b)
      end
      a
    end

    def copy(obj)
      if obj.is_a?(Hash)
        obj.each_with_object({}) do |(k,v),h|
          new_k = k.to_sym rescue k
          h[new_k] = copy(v)
        end
      elsif obj.is_a?(Array)
        obj.map {|e| copy e }
      else
        obj.dup
      end
    end

    def symbolize_keys(obj)
      if obj.is_a?(Hash)
        obj.each_with_object({}) do |(k,v),h|
          new_k = k.to_sym rescue k
          h[new_k] = symbolize_keys(v, &blk)
        end
      elsif obj.is_a?(Array)
        obj.map{|e| symbolize_keys(e, &blk)}
      else
        obj
      end
    end
  end
end
