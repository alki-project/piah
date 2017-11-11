require 'alki/feature_test'

describe "Mounted in Alki project" do
  before do
    @test_project = Alki::Test.fixture_path('mounted')
    $LOAD_PATH.unshift File.join(@test_project,'lib')
    require 'project'
    @app = Project.new
  end

  after do
    $LOADED_FEATURES.delete_if do |p|
      p.start_with?(File.join(@test_project,''))
    end
    $LOAD_PATH.delete_if do |p|
      p.start_with?(File.join(@test_project,''))
    end
    Object.send :remove_const, :Project
  end

  describe 'process' do
    it 'should process input using given config types' do
      @app.piah.process(as: [1,2,3], bs: [10]).must_equal(result: 'a1 a2 a3 b10')
    end
  end

end
