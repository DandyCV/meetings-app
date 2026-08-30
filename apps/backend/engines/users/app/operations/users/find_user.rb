module Users
  # Query: look up a user by primary key, or nil when there is no such user.
  class FindUser < Cqrs::Query
    def initialize(id:)
      @id = id
    end

    def call
      User.find_by(id: @id)
    end
  end
end
