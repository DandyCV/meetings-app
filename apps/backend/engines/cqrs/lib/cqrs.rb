# CQRS is the seam between application modules: a module exposes its use cases as
# commands (state changes) and queries (reads), and callers invoke them with
# `SomeOperation.call(...)` instead of reaching for another module's models.
module Cqrs
end

require "cqrs/callable"
require "cqrs/command"
require "cqrs/query"
require "cqrs/result"
