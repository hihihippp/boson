$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
%w{hirb alias}.each {|e| require e }
%w{runner runners/repl_runner repo manager loader inspector library}.each {|e| require "boson/#{e}" }
%w{argument method comment}.each {|e| require "boson/inspectors/#{e}_inspector" }
# order of library subclasses matters
%w{module file gem require}.each {|e| require "boson/libraries/#{e}_library" }
%w{namespace view command util commands option_parser index scientist}.each {|e| require "boson/#{e}" }

# This module stores the libraries, commands, repos and main object used throughout Boson.
module Boson
  # Module which is extended by Boson.main_object to give it command functionality.
  module Universe; include Commands::Namespace; end
  extend self
  # The object which holds and executes all command functionality
  attr_accessor :main_object
  attr_accessor :commands, :libraries
  alias_method :higgs, :main_object

  # Array of loaded Boson::Library objects.
  def libraries
    @libraries ||= Array.new
  end

  # Array of loaded Boson::Command objects.
  def commands
    @commands ||= Array.new
  end

  # The main required repository which defaults to ~/.boson.
  def repo
    @repo ||= Repo.new("#{ENV['HOME']}/.boson")
  end

  # An optional local repository which defaults to ./lib/boson or ./.boson.
  def local_repo
    @local_repo ||= begin
      dir = ["lib/boson", ".boson"].find {|e| File.directory?(e) &&
         File.expand_path(e) != repo.dir }
      Repo.new(dir) if dir
    end
  end

  # The array of loaded repositories
  def repos
    @repos ||= [repo, local_repo].compact
  end

  def main_object=(value) #:nodoc:
    @main_object = value.extend(Universe)
  end

  def library(query, attribute='name') #:nodoc:
    libraries.find {|e| e.send(attribute) == query }
  end

  # Start Boson by loading repositories and their configured libraries.
  # See ReplRunner.start for its options.
  def start(options={})
    ReplRunner.start(options)
  end

  # Invoke an action on the main object.
  def invoke(*args, &block)
    main_object.send(*args, &block)
  end

  # Boolean indicating if the main object can invoke the given method/command.
  def can_invoke?(meth)
    Boson.main_object.respond_to? meth
  end
end

Boson.main_object = self