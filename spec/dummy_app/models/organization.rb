require_relative 'draftable'

class Organization < Draftable
  has_many :memberships
  has_many :contact_addresses, as: :contactable

  validates :name, presence: true
end
