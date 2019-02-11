require_relative 'draftable'

class ContactAddressType < Draftable
  validates :name, presence: true
end
