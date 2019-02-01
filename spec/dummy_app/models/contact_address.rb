require_relative 'draftable'

class ContactAddress < Draftable
  belongs_to :contact_address_type
  belongs_to :contactable, polymorphic: true
end
