class Draft < ActiveRecord::Base
  belongs_to :draft_transaction
  belongs_to :draftable, polymorphic: true, optional: true

  validates :action_type, inclusion: { in: %w(CREATE UPDATE DELETE), message: "%{value} is not a valid Draft.action_type" }
end
