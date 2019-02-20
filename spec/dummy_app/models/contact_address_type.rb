require_relative 'draftable'

class ContactAddressType < Draftable
  validates :name, presence: true

  has_many :contact_addresses
end
