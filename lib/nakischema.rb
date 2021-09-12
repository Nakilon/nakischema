module Nakischema
  Error = Class.new RuntimeError

  def self.validate object, schema, path = []
    raise_with_path = lambda do |msg, _path = path|
      raise Error.new "#{msg}#{" (at #{_path})" unless _path.empty?}"
    end
    # TODO: maybe move '(at ...)' to the beginning
    case schema
    when NilClass, TrueClass, FalseClass, String, Symbol ; raise_with_path.call "expected #{schema.inspect} != #{object.inspect}" unless schema == object
    # TODO: maybe deprecate the NilClass, TrueClass, FalseClass since they can be asserted via the next case branch
    when Class                                           ; raise_with_path.call "expected #{schema        } != #{object.class  }" unless schema === object
    when Regexp                                          ; raise_with_path.call "expected #{schema        } != #{object.inspect}" unless schema === object
    when Range                                           ; raise_with_path.call "expected #{schema        } != #{object        }" unless schema.include? object
    when Hash
      raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash unless (schema.keys & %i{ keys each_key each_value }).empty?
      raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array unless (schema.keys & %i{ size }).empty?
      schema.each do |k, v|
        case k
        when :size ; raise_with_path.call "expected explicit size #{v} != #{object.size}" unless v.include? object.size
        # when Fixnum
        #   raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array
        #   validate object[k], v, [*path, :"##{k}"]
        when :keys ; validate object.keys, v, [*path, :keys]
        when :values ; validate object.values, v, [*path, :values]
        when :keys_sorted ; validate object.keys.sort, v, [*path, :keys_sorted]
        when :hash_opt ; v.each{ |k, v| validate object.fetch(k), v, [*path, k] if object.key? k }
        when :hash_req ; v.each{ |k, v| validate object.fetch(k), v, [*path, k] }
        when :hash     ; raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash
                         raise_with_path.call "expected implicit keys #{v.keys} != #{object.keys.sort}" unless v.keys.sort == object.keys.sort
                         v.each{ |k, v| validate object.fetch(k), v, [*path, k] }
        when :each_key ; object.keys.each_with_index{ |k, i| validate k, v, [*path, :"key##{i}"] }
        when :each_value ; object.values.each_with_index{ |v_, i| validate v_, v, [*path, :"value##{i}"] }
        when :each
          raise_with_path.call "expected iterable != #{object.class}" unless object.respond_to? :each_with_index
          object.each_with_index{ |e, i| validate e, v, [*path, :"##{i}"] }
        # when :case
        #   raise_with_path.call "expected at least one of #{v.size} cases to match the #{object.inspect}" if v.map.with_index do |(k, v), i|
        #     next if begin
        #       validate object, k
        #       nil
        #     rescue Error => e
        #       e
        #     end
        #     validate object, v, [*path, :"case##{i}"]
        #     true
        #   end.none?
        when :assertions
          v.each_with_index do |assertion, i|
            begin
              raise Error.new "custom assertion failed" unless assertion.call object, [*path, :"assertion##{i}"]
            rescue Error => e
              raise_with_path.call e, [*path, :"assertion##{i}"]
            end
          end
        else
          raise_with_path.call "unsupported rule #{k.inspect}"
        end
      end
    when Array
      if schema.map(&:class) == [Array]
        raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array
        raise_with_path.call "expected implicit size #{schema[0].size} != #{object.size} for #{object.inspect}" unless schema[0].size == object.size
        object.zip(schema[0]).each_with_index{ |(o, v), i| validate o, v, [*path, :"##{i}"] }
      else
        results = schema.lazy.with_index.map do |v, i|
          # raise_with_path.call "unsupported nested Array" if v.is_a? Array
          begin
            validate object, v, [*path, :"variant##{i}"]
            nil
          rescue Error => e
            e
          end
        end
        raise Error.new "expected at least one of #{schema.size} rules to match the #{object.inspect}, errors:\n" +
          results.force.compact.map{ |_| _.to_s.gsub(/^/, "  ") }.join("\n") if results.all?
      end
    else
      raise_with_path.call "unsupported rule class #{schema.class}"
    end
  end

  def self.validate_oga_xml object, schema, path = []
    raise_with_path = lambda do |msg, _path = path|
      raise Error.new "#{msg}#{" (at #{_path})" unless _path.empty?}"
    end
    case schema
    when String, Regexp ; raise_with_path.call "expected #{schema.inspect} != #{object.inspect}" unless schema === object
    when Hash
      schema.each do |k, v|
        case k
        when :size ; raise_with_path.call "expected explicit size #{v} != #{object.size}" unless v.include? object.size
        when :text ; raise_with_path.call "expected text #{v.inspect} != #{object.text.inspect}" unless v == object.text
        when :each ; raise_with_path.call "expected iterable != #{object.class}" unless object.respond_to? :each_with_index
                     object.each_with_index{ |e, i| validate_oga_xml e, v, [*path, :"##{i}"] }
        when :exact ; children = object.xpath "./*"
                      names = children.map(&:name).uniq
                      raise_with_path.call "expected implicit children #{v.keys} != #{names}" unless v.keys == names
                      v.each do |k, v|
                        selected = children.select{ |_| _.name == k }
                        validate_oga_xml selected, v, [*path, k]
                      end
        when :children ; v.each{ |k, v| validate_oga_xml object.xpath(k.start_with?("./") ? k : "./#{k}"), v, [*path, k] }
        when :attr_req ; v.each{ |k, v| validate_oga_xml object[k], v, [*path, k] }
        when :assertions
          v.each_with_index do |assertion, i|
            begin
              raise Error.new "custom assertion failed" unless assertion.call object, [*path, :"assertion##{i}"]
            rescue Error => e
              raise_with_path.call e, [*path, :"assertion##{i}"]
            end
          end
        else
          raise_with_path.call "unsupported rule #{k.inspect}"
        end
      end
    when Array
      if schema.map(&:class) == [Array]
        raise_with_path.call "expected implicit size #{schema[0].size} != #{object.size} for #{object.inspect}" unless schema[0].size == object.size
        object.zip(schema[0]).each_with_index{ |(o, v), i| validate_oga_xml o, v, [*path, :"##{i}"] }
      else
        results = schema.lazy.with_index.map do |v, i|
          begin
            validate_oga_xml object, v, [*path, :"variant##{i}"]
            nil
          rescue Error => e
            e
          end
        end
        raise Error.new "expected at least one of #{schema.size} rules to match the #{object.inspect}, errors:\n" +
          results.force.compact.map{ |_| _.to_s.gsub(/^/, "  ") }.join("\n") if results.all?
      end
    else
      raise_with_path.call "unsupported rule class #{schema.class}"
    end
  end
end
