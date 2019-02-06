require_relative 'draftable'

class Person < Draftable
  belongs_to :gender, optional: true

  has_many :memberships
  has_many :contact_addresses, as: :contactable
end
