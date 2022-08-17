# Nakischema

## Why?

I often process complex and undocumented data such as game assets or web responses. Previously I used to add asserts everywhere to check things on the fly but now I think the much better practice is to split the job into two steps and preprocess the whole data, i.e. validate it, before starting the actual work with it, because:

1. Having asserts in random places may cause running them more than once for no purpose.
2. Having asserts at all is just slowing your program.
3. It is much simpler to figure things out after you've processed all the data. Valid schema is a valid documentation.

The whole Nakischema API is just one method.  
The whole schema is just one Ruby object.  
Say no to needless DSLs.

Also exceptions are informative -- they tell you where and how things went wrong.

## How?

### Install

```bash
gem install nakischema
```
```ruby
require "nakischema"
```

### Validate Ruby objects

Schema can be as simple as just checking basic scalar objects for equality or class:

```ruby
Nakischema.validate "John", String  # => nil
Nakischema.validate "John", "Joe"   # Nakischema::Error: expected "Joe" != "John"
Nakischema.validate "John", Numeric # Nakischema::Error: expected Numeric != String
```

And schema can be nested to validate nested objects.  
Array and Hash objects have to be validated by Hash object schema with special keys:
* `:each` for validating every Array item with nested schema object
* `:hash` for validating every value via exact Hash keys match

```ruby
Nakischema.validate( [
  {name: "John", age: 20},
  {name: "Bill", age: 15},
], {
  each: {
    hash: {
      name: /\A[A-Z][a-z]+\z/,
      age: 18..100,
    },
  },
} )
```
```none
expected 18..100 != 15 (at [:"#1", :age]) (Nakischema::Error)
```

* `:size` to specify allowed Array size range
* `:hash_req` to specify required Hash items
* `:hash_opt` to specify optional Hash items

Your schema object can be recursive to validate objects that are recursive or just look like that:

```ruby
human_schema = {}
human_schema.replace( {
  hash_req: {name: /\A[A-Z][a-z]+\z/, age: 0..100},
  hash_opt: {parents: {size: 2..2, each: human_schema}},
} )

father = {name: "John", age: 40}
mother = {name: "Anna", age: 40}
Nakischema.validate( [
  father,
  mother,
  {name: "Bill", age: 18, parents: [father, mother]},
],
  {each: human_schema}
)
```

The `[[ ]]` syntax validates an Array in order (it also can be nested).

```ruby
pets = [
  ["cat", "Thomas"],
]
Nakischema.validate( pets, {
  each: [[/\A[a-z]+\z/, /\A[A-Z]/]]
} )
```

The "or-group" `[ ]` tries to match the object with any of a given list of "rules" (schemas).
* `:assertions` allows passing a list of lambdas to do arbitrary checks and return booleans. 

```ruby
humans = [
  {name: "John", gender: :male},
  {name: "Anna", gender: :female, pets: %w{ Thomas }},
  {name: "Bill", gender: :attack_helicopter},
]
Nakischema.validate( humans, {
  each: {
    hash_opt: {
      pets: {
        each: {
          assertions: [
            -> pet_id, _ { pets.map(&:last).include? pet_id },
          ],
        }
      },
    },
    hash_req: {
      name: /\A[A-Z]/,
      gender: [:male, :female],
    },
  },
} )
```
```none
expected at least one of 2 rules to match the :attack_helicopter, errors: (Nakischema::Error)
  expected :male != :attack_helicopter (at [:"#2", :gender, :"variant#0"])
  expected :female != :attack_helicopter (at [:"#2", :gender, :"variant#1"])
```

Here you can see that nested schema validation errors produce nested exception messages with indentation so you can easily see the whole validation object tree path that was made.

And if Anna had a pet with unfamiliar name that custom assertion would throw:
```none
custom assertion failed (at [:"#1", :pets, :"#0"]) (Nakischema::Error)
```

Known issue and workaround: the `[[[]]]` is being interpereted as `[[ [] ]]`, not `[ [[]] ]`, but you can force it by doing: `[:something, [[]]]`.

There are a few other special keys. You'll find them in source code easily.

### Validate Oga objects

[`gem oga`](https://rubygems.org/gems/oga) is a Nokogiri analogue that I recommend you to try out because it's written in pure Ruby. `Nakischema.validate_oga_xml` is a method more or less similar to `validate`. See basic [Wolfram Alpha API](https://products.wolframalpha.com/api/) response validation as an example:

```ruby
xml = Oga.parse_xml open link, &:read
Nakischema.validate_oga_xml xml, {
  exact: {
    "queryresult" => [[ {
      attr_req: {"success": "true", "error": "false", "inputstring": query},
      assertions: [
        ->n,_{ n.at_xpath("./pod")["id"] == "Input" },
        ->n,_{ n.xpath("/pod").each{ |_| _["id"] == _["title"].delete(" ") } },
      ],
      exact: {"pod" => {size: 8..8}, "assumptions" => [[{}]]},
      children: {
        "/*[@error='true']" => [[]],
        "/pod" => {each: {attr_req: {"id": /\A([A-Z][a-z]+)+(:([A-Z][a-z]+)+)?\z/, "scanner": /\A([A-Z][a-z]+)+\z/}}},
        "./pod[@title='Input']" => [[{children: {"subpod" => [[{exact: {"plaintext" => [[{text: query}]]}}]]}}]],
        "./pod[@primary='true']" => [[{children: {"subpod" => [[{exact: {"plaintext" => [[{}]]}}]]}}]],
        "/pod[@scanner='Numeric']" => {each: {children: {"subpod" => [[{exact: {"plaintext" => [[{}]]}}]]}}},
      },
    } ]],
  },
}
```

* `exact` -- similar to `hash` when using `validate`  
* `attr_req` -- required attributes  
* `children` -- children nodes  
* `text` -- ...text

`exact` and `req` accept either node name or XPath. Each results in an array of nodes of any length, even empty -- this is why you see so many `[[]]`. Also note that results of these selectors can overlap so you are able to apply multiple schemas to the same node.

### Another real life example -- validating non-json object while using `gem minitest`

Imagine you want to validate the args that were passed to `Monitoring.log` when calling the `log_ruby_processes`. First you write such test to see the actual args passed:

```ruby
it :log_ruby_processes do
  mock = MiniTest::Mock.new.expect :call, nil do |*args|

    require "pp"
    pp args

  end
  Monitoring.stub :log, mock do

    log_ruby_processes

  end
  mock.verify
end
```

```none
$ ruby test.rb
...
[2021-09-06 00:59:58 UTC,
 nil,
 {:total=>3,
  :each=>
   [["/Users/nakilon/.../ruby test.rb", 35.53125, 43],
    ["/Users/nakilon/.../ruby take.rb", 3.20703125, 41],
    ["/Users/nakilon/.../bin/paster", 1.89453125, 14]]}]
...
```

Now just replace the `require "pp"; pp args` with something like this:

```ruby
    Nakischema.validate args, [[
      Time,
      NilClass,
      {
        hash: {
          total: 3..3,
          each: {
            size: 3..3,
            each: [[/\A\/Users\//, Float, Fixnum]],
          },
        },
        assertions: [-> h,_ { h[:total] == h[:each].size }],
      },
    ]]
```

### Custom mismatch message

Imagine you don't want a number higher than 5 (unless it's 10):

```ruby
Nakischema.validate [1, 10, 7], {
  each: [
    { assertions: [-> x, _ {
      x <= 5
    } ] },
    10..10,
  ],
}
```
```none
expected at least one of 2 rules to match the 7, errors: (Nakischema::Error)
  custom assertion failed (at [:"#2", :"variant#0", :"assertion#0"])
  expected 10..10 != 7 (at [:"#2", :"variant#1"])
```

To replace the generic "custom assertion failed" message with something more useful you can raise the `Nakischema::Error` manually (don't forget to return `true` otherwise):

```ruby
Nakischema.validate [1, 10, 7], {
  each: [
    { assertions: [-> x, _ {
      raise Nakischema::Error.new "#{x} is too much" unless x <= 5
      true
    } ] },
    10..10,
  ],
}
```
```none
expected at least one of 2 rules to match the 7, errors: (Nakischema::Error)
  7 is too much (at [:"#2", :"variant#0", :"assertion#0"])
  expected 10..10 != 7 (at [:"#2", :"variant#1"])
```

## Why such stupid name?

Initially I wanted to call it something like "SchemaValidator" but:

```none
$ gem search schema | grep valid
...
schema-validator (0.0.1)
schema_validations (2.3.0)
schema_validator (0.1.1)
validates_by_schema (0.4.0)
validates_schema (1.1.3)
...
$ gem search schema | wc -l
288
```

## TODO

* make some tests and GitHub Action for them
* consider replacing `.is_a?` with `.respond_to?`
* ability to assert at the same time the range and class (like is it's float or integer)
