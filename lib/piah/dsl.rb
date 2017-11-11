Alki do
  require_dsl 'alki/dsls/service'

  init do
    @auto_outputs = []
    @types = {}
    @has_process =false
  end

  dsl_method :input do |type,*args|
    raise ArgumentError.new "Too many arguments" if args.size > 1
    if type.is_a?(Hash) && type.size == 1
      type, *args = type.to_a.first
    end
    has_default = !args.empty?
    default = args.first
    @types[type] = !has_default
    add_method type, private: true, subclass: 'Instance' do
      @_values[type] || default
    end
  end

  dsl_method :passthrough do |type,*args|
    input type, *args
    @auto_outputs << type
  end

  dsl_method :process do |&blk|
    @has_process = true
    add_method :process, subclass: 'Instance', &blk
  end

  finish do
    unless @has_process
      raise "Processor must have process block!"
    end
    types = @types.keys
    required_types = @types.inject([]) {|a,(n,r)| r ? a << n : a }.to_set
    auto_outputs = @auto_outputs

    ivs = class_builder[:initialize_params]&.map {|n,_| :"@#{n}"} || []

    add_module ctx[:module], subclass: 'Instance'
    ctx[:module] = nil
    add_method :initialize, subclass: 'Instance' do |config_type,values,output|
      @_config_type = config_type
      ivs.each do |iv|
        instance_variable_set iv, config_type.instance_variable_get(iv)
      end
      @_values = values
      @_output = output
    end

    add_method :output, subclass: 'Instance' do |*keys,value,&blk|
      if blk
        keys << value
        value = blk
      end
      @_output << keys.reverse.inject(value) do |v,k|
        {k => v}
      end
    end

    add_method :types do
      types
    end

    add_method :process do |args|
      output = []
      unless auto_outputs.empty?
        output << auto_outputs.map do |o|
          args.key?(o) ? [o,args[o]] : nil
        end.compact.to_h
      end
      unless required_types <= args.keys.to_set
        return output
      end
      instance = self.class::Instance.new self, args, output
      if instance.respond_to? :process
        instance.process
      end
      output
    end
  end
end
