require "minitest/autorun"

require_relative "lib/nakischema"
describe Nakischema do
  it do
    c = Class.new
    Nakischema.validate [
      nil, true, false, :symbol, "string",
      c.new, "", 1,
      [], {},
      {4=>3, 2=>1},
    ], [[
      nil, true, false, :symbol, "string",
      c, /\A\z/, [nil, 1..1],
      {size: 0..0}, {hash_opt: {""=>""}, assertions: [->_,__{ _.empty? }]},
      {keys: [[4..4, 2..2]], values: [[3..3, 1..1]], keys_sorted: [[2..2, 4..4]], hash_req: {2=>1..1}, each: [[2..4, 1..3]]},
    ]]
  end
end
