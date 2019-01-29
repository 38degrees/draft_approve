class Person < ActiveRecord::Base
  has_drafts

  belongs_to :gender, optional: true

  has_many :memberships
  has_many :contact_addresses
end
