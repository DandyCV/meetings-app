require "cqrs"

# Users owns the account record and every read/write against it: registering a
# new account, looking one up by id, and checking a password. Other modules must
# not touch Users::User directly — they call these operations.
module Users
end

require "users/engine"
