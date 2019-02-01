require_relative 'draftable'

class Membership < Draftable
  belongs_to :person
  belongs_to :organization
  belongs_to :role, optional: true

  has_many :contact_addresses
end
