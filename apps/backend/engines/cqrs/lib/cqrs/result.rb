module Cqrs
  # The outcome of a command that can fail with validation errors. Queries and
  # always-succeeding commands return their value directly instead.
  class Result
    attr_reader :value, :errors

    def self.success(value)
      new(success: true, value: value)
    end

    def self.failure(errors)
      new(success: false, errors: Array(errors))
    end

    def initialize(success:, value: nil, errors: [])
      @success = success
      @value = value
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
