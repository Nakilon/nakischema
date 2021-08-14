# Why?

I often process complex and undocumented data such as game assets or web responses. Previously I used to add asserts everywhere in code that uses the data but now I think it's much better to split the job into two steps and preprocess the whole data, i.e. validate it, because:

1. Having asserts in random places may cause running them more than once for no purpose.
2. Having asserts at all is just slowing your program.
3. It is much simplier to figure things out after you've processed all the data. Valid schema is a valid documentation.

The whole API is just one method.
The whole schema is just one nested Hash object.
Say no to needless DSLs.

Also exceptions are informative -- they tell you where and how things went wrong.

# How?

```bash
gem install nakischema
```
```ruby
require "nakischema"
schema = { ... }
Nakischema.validate data, schema
```



# Why such stupid name?

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

Also nowadays there is a trend anyway to add the same brand prefix to your gem names, such as `dry-*` even if gems are not related and if the prefix means nothing, i.e. they aren't DRY. Just a SEO marketing practice. Blame yourself for starting it ..P

# TODO

* make some tests
