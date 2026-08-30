module Cqrs
  # Turns an operation object into a one-shot callable: `Operation.call(**args)`
  # builds an instance and runs `#call` on it.
  module Callable
    def call(*args, **kwargs)
      new(*args, **kwargs).call
    end
  end
end
