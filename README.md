# Why?

I often process complex and undocumented data such as game assets or web responses.
It is much simplier to figure things out if you start with validating all the data.

# How?

```bash
gem install nakischema
```
```ruby
require "nakischema"
schema = { ... }
Nakischema.validate data, schema
```

# Examples



# TODO

* push to rubygems
* make some tests
