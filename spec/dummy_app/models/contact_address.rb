class ContactAddress < ActiveRecord::Base
  has_drafts

  belongs_to :contact_address_type
  belongs_to :contactable, polymorphic: true
end
