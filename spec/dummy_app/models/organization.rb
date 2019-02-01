require_relative 'draftable'

class Organization < Draftable
  has_many :memberships
  has_many :contact_addresses
end
