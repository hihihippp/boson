require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LoaderTest < Test::Unit::TestCase
    def load(lib, options={})
      unless lib.is_a?(Module)
        File.expects(:exists?).with(Loader.library_file(lib.to_s)).returns(true)
        File.expects(:read).returns(options.delete(:file_string))
      end
      Library.load([lib], options)
    end

    def library(name)
      Boson.libraries.find_by(:name=>name)
    end

    context "create" do
      #resets lib_config
    end

    context "load_and_create" do
      before(:each) { reset_libraries; reset_commands }
      test "loads a module" do
        eval %[module ::Harvey; def bird; end; end]
        load ::Harvey
        Library.loaded?('harvey').should == true
        command_exists?('bird').should == true
      end

      test "loads a basic library" do
        capture_stdout {
          load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
        }.should =~ /included blah/
        Library.loaded?('blah').should == true
        command_exists?('blah').should == true
        library('blah')[:module].is_a?(Module).should == true
        library('blah')[:module].to_s.should == "Boson::Libraries::Blah"
      end

      test "loads a library in a subdirectory" do
        load 'site/delicious', :file_string=>"module Delicious; def bundles; end; end"
        Library.loaded?("site/delicious").should == true
        command_exists?('bundles').should == true
        library('site/delicious')[:module].is_a?(Module).should == true
        library('site/delicious')[:module].to_s.should == "Boson::Libraries::Delicious"
      end

      test "loads a polluting gem" do
        File.expects(:exists?).returns(false)
        Util.expects(:safe_require).with { eval "module ::Kernel; def dude; end; end"; true}.returns(true)
        Library.load ["dude"]
        Library.loaded?("dude").should == true
        command_exists?("dude").should == true
      end

      test "loads a normal gem" do
        File.expects(:exists?).returns(false)
        Util.expects(:safe_require).with { eval "module ::Dude2; def dude2; end; end"; true}.returns(true)
        with_config(:libraries=>{"dude2"=>{:module=>'Dude2'}}) do
          Library.load ["dude2"]
          Library.loaded?("dude2").should == true
          command_exists?("dude2").should == true
          library('dude2')[:module].should == ::Dude2
        end
      end

      # load lib w/ deps
      # method conflicts
      # :object_commands
      # :call_methods
      # :no_module_eval/:module
      # :force
      #resets lib_config
    end
    # *Error
  end
end