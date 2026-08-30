module Cqrs
  # A query reads state and never mutates it. Subclasses implement `#call`.
  class Query
    extend Callable
  end
end
