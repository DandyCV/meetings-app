require "cqrs"

# Auth owns everything about API tokens — minting them for a user id and
# resolving a user id back from a token. It has no knowledge of the User model
# or the database; callers pair it with the Users module.
module Auth
end

require "auth/engine"
require "auth/token_codec"
