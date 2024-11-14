module Nakischema
  Error = Class.new RuntimeError

  def self.validate _object, _schema, message = nil
    function = lambda do |object, schema, path|
    raise_with_path = lambda do |msg, _path = path|
        # TODO: maybe move '(at ...)' to the beginning
        raise Error, "#{msg}#{" (at #{_path})" unless _path.empty?}#{
          block_given? ? " #{yield(object)}" : (" #{message}" if message)
        }"
    end
    case schema
    when NilClass, TrueClass, FalseClass, String, Symbol ; raise_with_path.call "expected #{schema.inspect} != #{object.inspect}" unless schema === object
    # TODO: maybe deprecate the NilClass, TrueClass, FalseClass since they can be asserted via the next case branch
    when Class                                           ; raise_with_path.call "expected #{schema        } != #{object.class  }" unless schema === object
    when Regexp                                          ; raise_with_path.call "expected #{schema        } != #{object.inspect}" unless schema === object
    when Range                                           ; raise_with_path.call "expected #{schema        } != #{object.inspect}" unless schema.include? object
    when Hash
      raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash unless (schema.keys & %i{ keys each_key each_value }).empty?
      raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array unless (schema.keys & %i{ size }).empty?   # TODO: maybe allow Hash object?
      schema.each do |k, v|
        case k
        when :size ; raise_with_path.call "expected Range != #{v.class}" unless v.is_a? Range
                     raise_with_path.call "expected explicit size #{v} != #{object.size}" unless v.include? object.size
        # when Fixnum
        #   raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array
        #   validate object[k], v, path: [*path, :"##{k}"]
          when :keys ; function.call object.keys, v, path: [*path, :keys]
          when :values ; function.call object.values, v, path: [*path, :values]
          when :keys_sorted ; function.call object.keys.sort, v, path: [*path, :keys_sorted]   # TODO: maybe copypaste the Array validation to reduce [] nesting
        when :hash_opt ; raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash
                         v.each{ |k, v| function.call object.fetch(k), v, path: [*path, k] if object.key? k }
        when :hash_req ; raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash
                         raise_with_path.call "expected required keys #{v.keys.sort} ∉ #{object.keys.sort}" unless (v.keys - object.keys).empty?
                         v.each{ |k, v| function.call object.fetch(k), v, path: [*path, k] }
        when :hash     ; raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash
                         hash_wo_opt = object.keys.sort - schema.fetch(:hash_opt, {}).keys
                         raise_with_path.call "expected implicit keys #{v.keys.sort} != #{hash_wo_opt}" unless v.keys.sort == hash_wo_opt
                         v.each{ |k, v| function.call object.fetch(k), v, path: [*path, k] }
          when :each_key ; object.keys.each_with_index{ |k, i| function.call k, v, path: [*path, :"key##{i}"] }
          when :each_value ; object.values.each_with_index{ |v_, i| function.call v_, v, path: [*path, :"value##{i}"] }
          when :method ; v.each{ |m, e| function.call object.public_method(m).call, e, path: [*path, :"method##{m}"] }
        when :each
          raise_with_path.call "expected iterable != #{object.class}" unless object.respond_to? :each_with_index
          object.each_with_index{ |e, i| function.call e, v, path: [*path, :"##{i}"] }
        # when :case
        #   raise_with_path.call "expected at least one of #{v.size} cases to match the #{object.inspect}" if v.map.with_index do |(k, v), i|
        #     next if begin
        #       validate object, k
        #       nil
        #     rescue Error => e
        #       e
        #     end
        #     validate object, v, path: [*path, :"case##{i}"]
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
          object.zip(schema[0]).each_with_index{ |(o, v), i| function.call o, v, path: [*path, :"##{i}"] }
      else
        results = schema.lazy.with_index.map do |v, i|
          # raise_with_path.call "unsupported nested Array" if v.is_a? Array
          begin
              function.call object, v, path: [*path, :"variant##{i}"]
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
    function.call _object, _schema, []
  end

  def self.valid? object, schema
    validate object, schema
    true
  rescue Error
    false
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
                      v.each{ |k, v| validate_oga_xml children.select{ |_| _.name == k }, v, [*path, k] }
        when :children   ; v.each{ |k, v| validate_oga_xml object.xpath(k.start_with?("./") ? k : "./#{k}"), v, [*path, k] }
        when :attr_exact ; names = object.attributes.map &:name
                           raise_with_path.call "expected implicit attributes #{v.keys} != #{names}" unless v.keys == names
                           v.each{ |k, v| validate_oga_xml object[k], v, [*path, k] }
        when :attr_req   ; v.each{ |k, v| validate_oga_xml object[k], v, [*path, k] }
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

  def self.fixture _, no_shuffle = false
    require "regexp-examples"
    require "addressable"
    case _
    when NilClass ; nil
    when Hash
      case _.keys
      when %i{ hash     } ;   _[:hash    ].map{ |k,v| [k,fixture(v,no_shuffle)] }                .then{ |_| no_shuffle ? _ : _.shuffle }.to_h
      when %i{ hash_req } ; [*_[:hash_req].map{ |k,v| [k,fixture(v,no_shuffle)] }, ["foo","bar"]].then{ |_| no_shuffle ? _ : _.shuffle }.to_h   # TODO: assert no collision
      when %i{ size each } ; Array.new(_[:size].max){ fixture _[:each], no_shuffle }
      else ; fail _.keys.inspect
      end
    when Array ; [Array] == _.map(&:class) ? _[0].map{ |_| fixture _, no_shuffle } : fixture(_.sample, no_shuffle)
    when Regexp
      begin
        URI(t = _.random_example)
      rescue URI::InvalidURIError
        begin
          URI Addressable::URI.escape t
        rescue Addressable::URI::InvalidURIError
          t
        end
      end.to_s
    when Range ; rand _
    when String ; _
    when TrueClass ; true
    when Class
      case _.name
      when "Integer" ; -rand(1000000)
      when "String" ; SecureRandom.random_bytes(1000).force_encoding("utf-8").scrub
      when "Hash" ; {}
      else ; fail "bad fixture node class name: #{_.name}"
      end
    else ; fail "bad fixture node class: #{_.class.inspect}"
    end
  end

end
