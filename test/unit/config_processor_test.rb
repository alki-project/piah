require 'alki/test'

require 'piah/config_processor'

describe Piah::ConfigProcessor do
  before do
    @processor = MiniTest::Mock.new
    @cp = Piah::ConfigProcessor.new @processor
  end

  def types(*types)
    @processor.expect(:types,types.each_index.zip(types).to_h,[])
  end

  describe :process do
    it 'should call #process on the processors for each config item' do
      types [:a], [:a]
      config = {a: 1, b: 2}

      @processor.expect :process, {}, [0, {a: 1}]
      @processor.expect :process, {}, [1, {a: 1}]

      @cp.process(config).must_equal({b: 2})
    end

    it 'should call #process for each processor with only available config items' do
      types [:a,:b,:c], [:a, :b]
      config = {c: 1}

      @processor.expect :process, {}, [0, {c: 1}]
      @processor.expect :process, {}, [1, {}]

      @cp.process(config).must_equal({})
    end

    it 'should process results of executed processors' do
      types [:a], [:b]
      config = {a: 1}

      # Run a
      @processor.expect :process, {b: 2}, [0,{a: 1}]

      # Run new b config
      @processor.expect :process, {c: 3}, [1,{b: 2}]


      @cp.process(config).must_equal(c: 3)
    end

    it 'should merge config items from results of processors' do
      types [:a], [:b], [:c]
      config = {a: 1,b: [1],c:{a: 1}}
      # Run a config
      @processor.expect :process, {b: [2],c: {b: 2}}, [0,{a: 1}]

      # Run b and c config but with merged results from a
      @processor.expect :process, {d: [1]}, [1,{b: [1,2]}]
      @processor.expect :process, {d: [2]}, [2,{c: {a: 1,b: 2}}]

      @cp.process(config).must_equal(d: [1,2])
    end

    it 'should rerun processors when their config changes' do
      types [:a], [:b]
      config = {a: [1], b: {a: 1}}
      # Process a and b
      @processor.expect :process, {d: [4]}, [0,{a: [1]}]
      @processor.expect :process, {a: [2],d: [1]}, [1,{b: {a: 1}}]

      # a config changed so rerun
      @processor.expect :process, {d: [2,3]}, [0,{a: [1,2]}]

      @cp.process(config).must_equal(d: [1,2,3])
    end

    it 'should not use version of config items returned by their own processor' do
      types [:a], [:b], [:c]
      config = {b: [1]}
      # Process a and b
      @processor.expect :process, {b: [2]}, [0,{}]
      @processor.expect :process, {b: [3]}, [1,{b: [1,2]}]
      @processor.expect :process, {b: [3]}, [2,{}]
      @processor.expect :process, {b: [6]}, [1,{b: [1,2,3]}]

      @cp.process(config).must_equal(b: [6])
    end

    it 'should not allow processors to modify inputs' do
      types [:a], [:a]
      config = {a: [1]}

      @processor.expect :process, {} do |i,a:|
        a.push 2
        i == 0
      end
      @processor.expect :process, {}, [1,{a: [1]}]
      @cp.process(config).must_equal({})
    end

    it 'should raise error if processor returns a non-hash' do
      types []
      config = {}
      @processor.expect :process, 1, [0,{}]

      assert_raises Piah::ConfigProcessorResultError do
        @cp.process(config)
      end
    end

    it 'should raise error if trying to merge incompatible configs' do
      config = {a: 1, b: [1], c: {a: 1}}

      types []
      @processor.expect :process, {a: 2}, [0,{}]
      assert_raises Piah::ConfigMergeError do
        @cp.process(config)
      end

      types []
      @processor.expect :process, {b: 1}, [0,{}]
      assert_raises Piah::ConfigMergeError do
        @cp.process(config)
      end

      types []
      @processor.expect :process, {b: {}}, [0,{}]
      assert_raises Piah::ConfigMergeError do
        @cp.process(config)
      end

      types []
      @processor.expect :process, {c: {a: [1]}}, [0,{}]
      assert_raises Piah::ConfigMergeError do
        @cp.process(config)
      end
    end
  end
end
