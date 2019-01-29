class Organization < ActiveRecord::Base
  has_drafts

  has_many :memberships
  has_many :contact_addresses
end
