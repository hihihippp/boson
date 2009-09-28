require 'shellwords'
module Boson
  module Higgs
    extend self
    class Error < StandardError; end
    class EscapeGlobalOption < StandardError; end
    attr_reader :global_options

    def create_option_command(obj, command)
      cmd_block = create_option_command_block(obj, command)
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    end

    def create_option_command_block(obj, command)
      lambda {|*args|
        Boson::Higgs.translate_and_render(obj, command, args) {|args| super(*args) }
      }
    end

    def translate_and_render(obj, command, args)
      @global_options = {}
      args = translate_args(obj, command, args)
      puts "Debug: #{args.inspect}" if @global_options[:debug]
      render yield(args)
    rescue EscapeGlobalOption
      Boson.invoke(:usage, command.name) if @global_options[:help]
    rescue OptionParser::Error, Error
      $stderr.puts "Error: " + $!.message
      $stderr.puts $!.backtrace.inspect if @global_options[:debug]
    end

    def translate_args(obj, command, args)
      @obj, @command, @args = obj, command, args
      if parsed_options = command_options
        add_default_args(@args)
        @args << parsed_options
        if @args.size != command.arg_size && !command.has_splat_args?
          command_size = @args.size > command.arg_size ? command.arg_size : command.arg_size - 1
          raise ArgumentError, "wrong number of arguments (#{@args.size - 1} for #{command_size})"
        end
      end
      @args
    rescue Error, ArgumentError, EscapeGlobalOption
      raise
    rescue Exception
      raise Error, $!.message
    end

    def render(result)
      render? ? Boson.invoke(:render, result, global_render_options) : result
    rescue Exception
      raise Error, $!.message
    end

    def option_parser
      @command.render_options ? command_option_parser : default_option_parser
    end

    def command_option_parser
      (@option_parsers ||= {})[@command] ||= begin
        OptionParser.new Util.recursive_hash_merge(default_options, @command.render_options)
      end
    end

    def default_option_parser
      @default_option_parser ||= OptionParser.new(default_options)
    end

    def default_options
      {:help=>:boolean, :render=>:boolean, :debug=>:boolean, :global=>:string}.merge(render_options)
    end

    def render_options
      {:fields=>{:type=>:array}, :sort=>{:type=>:string}, :as=>:string, :reverse_sort=>:boolean}
    end

    def global_render_options
      @global_options.dup.delete_if {|k,v| !render_options.keys.include?(k) }
    end

    def render?
      (@command.render_options && !@global_options[:render]) || (!@command.render_options && @global_options[:render])
    end

    def command_options
      if @args.size == 1 && @args[0].is_a?(String)
        parsed_options, @args = parse_options Shellwords.shellwords(@args[0])
      # last string argument interpreted as args + options
      elsif @args.size > 1 && @args[-1].is_a?(String)
        parsed_options, new_args = parse_options @args.pop.split(/\s+/)
        @args += new_args
      # default options
      elsif (@args.size <= @command.arg_size - 1) || (@command.has_splat_args? && !@args[-1].is_a?(Hash))
        parsed_options = parse_options([])[0]
      end
      parsed_options
    end

    def parse_options(args)
      parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
      @global_options = option_parser.parse @command.option_parser.leading_non_opts
      new_args = option_parser.non_opts.dup + @command.option_parser.trailing_non_opts
      if @global_options[:global]
        global_opts = Shellwords.shellwords(@global_options[:global]).map {|str| (str.length > 1 ? "--" : "-") + str }
        @global_options.merge! option_parser.parse(global_opts)
      end
      raise EscapeGlobalOption if @global_options[:help]
      [parsed_options, new_args]
    end

    def add_default_args(args)
      if @command.args && args.size < @command.args.size - 1
        # leave off last arg since its an option
        @command.args.slice(0..-2).each_with_index {|arr,i|
          next if args.size >= i + 1 # only fill in once args run out
          break if arr.size != 2 # a default arg value must exist
          begin
            args[i] = @command.file_parsed_args? ? @obj.instance_eval(arr[1]) : arr[1]
          rescue Exception
            raise Error, "Unable to set default argument at position #{i+1}.\nReason: #{$!.message}"
          end
        }
      end
    end
  end
end