module Cqrs
  # A command changes state (create/update/delete). Subclasses implement `#call`.
  class Command
    extend Callable
  end
end
