module DraftApprove
  class Draft < ActiveRecord::Base
    CREATE = 'CREATE'.freeze
    UPDATE = 'UPDATE'.freeze
    DELETE = 'DELETE'.freeze

    belongs_to :draft_transaction
    belongs_to :draftable, polymorphic: true, optional: true

    validates :action_type, inclusion: { in: [CREATE, UPDATE, DELETE], message: "%{value} is not a valid Draft.action_type" }
  end
end
