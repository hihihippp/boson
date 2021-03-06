module Boson
  # Collection of utility methods used throughout Boson.
  module Util
    extend self
    # From ActiveSupport, converts a camelcased string to an underscored string:
    # 'Boson::MethodInspector' -> 'boson/method_inspector'
    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
       gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
       gsub(/([a-z\d])([A-Z])/,'\1_\2').
       tr("-", "_").
       downcase
    end

    # From ActiveSupport, does the reverse of underscore:
    # 'boson/method_inspector' -> 'Boson::MethodInspector'
    def camelize(string)
      string.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.
        gsub(/(?:^|_)(.)/) { $1.upcase }
    end

    # Converts a module/class string to the actual constant.
    # Returns nil if not found.
    def constantize(string)
      any_const_get(camelize(string))
    end

    # Returns a constant like const_get() no matter what namespace it's nested
    # in. Returns nil if the constant is not found.
    def any_const_get(name)
      return name if name.is_a?(Module)
      klass = Object
      name.split('::').each {|e|
        klass = klass.const_get(e)
      }
      klass
    rescue
       nil
    end

    # Detects new object/kernel methods, gems and modules created within a
    # block. Returns a hash of what's detected. Valid options and possible
    # returned keys are :methods, :object_methods, :modules, :gems.
    def detect(options={}, &block)
      options = {methods: true}.merge!(options)
      original_gems = defined?(Gem) ? Gem.loaded_specs.keys : []
      original_object_methods = Object.instance_methods
      original_instance_methods = Boson.main_object.singleton_class.instance_methods
      original_modules = modules if options[:modules]

      block.call

      detected = {}
      detected[:methods] = options[:methods] ?
        (Boson.main_object.singleton_class.instance_methods -
           original_instance_methods) : []
      unless options[:object_methods]
        detected[:methods] -= (Object.instance_methods - original_object_methods)
      end
      detected[:gems] = Gem.loaded_specs.keys - original_gems if defined? Gem
      detected[:modules] = modules - original_modules if options[:modules]
      detected
    end

    # Returns all modules that currently exist.
    def modules
      all_modules = []
      ObjectSpace.each_object(Module) {|e| all_modules << e}
      all_modules
    end

    # Creates a module under a given base module and possible name. If the
    # module already exists, it attempts to create one with a number appended to
    # the name.
    def create_module(base_module, name)
      desired_class = camelize(name)
      possible_suffixes = [''] + %w{1 2 3 4 5 6 7 8 9 10}
      if suffix = possible_suffixes.find {|e|
        !base_module.const_defined?(desired_class+e) }
          base_module.const_set(desired_class+suffix, Module.new)
      end
    end

    # Recursively merge hash1 with hash2.
    def recursive_hash_merge(hash1, hash2)
      hash1.merge(hash2) {|k,o,n| (o.is_a?(Hash)) ? recursive_hash_merge(o,n) : n}
    end

    # Regular expression search of a list with underscore anchoring of words.
    # For example 'some_dang_long_word' can be specified as 's_d_l_w'.
    def underscore_search(input, list, first_match=false)
      meth = first_match ? :find : :select
      return (first_match ? input : [input]) if list.include?(input)
      input = input.to_s
      if input.include?("_")
        underscore_regex = input.split('_').map {|e|
          Regexp.escape(e) }.join("([^_]+)?_")
        list.send(meth) {|e| e.to_s =~ /^#{underscore_regex}/ }
      else
        escaped_input = Regexp.escape(input)
        list.send(meth) {|e| e.to_s =~ /^#{escaped_input}/ }
      end
    end

    def format_table(arr_of_arr)
      name_max = arr_of_arr.map {|arr| arr[0].length }.max
      desc_max = arr_of_arr.map {|arr| arr[1].length }.max

      arr_of_arr.map do |name, desc|
        ("  %-*s  %-*s" % [name_max, name, desc_max, desc]).rstrip
      end
    end
  end
end
