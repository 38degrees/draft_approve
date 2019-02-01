# IMPORTANT NOTE: These constants are written to the database, so cannot be
# updated without requiring a (potentially very slow) migration of all
# existing draft data

module DraftApprove
  # Constants to define & store the type of action a draft is performing
  CREATE = 'create'.freeze
  UPDATE = 'update'.freeze
  DELETE = 'delete'.freeze

  # Constants to define the hash keys in drafts used to point to associations
  # (these are similar to how ActiveRecord polymorphic associations work)
  TYPE = 'type'.freeze
  ID = 'id'.freeze
end
