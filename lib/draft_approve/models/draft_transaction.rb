class DraftTransaction < ActiveRecord::Base
  has_many :drafts

  def approve_changes
    ActiveRecord::Base.transaction do
      drafts.order(:created_at, :id).each do |draft|
        draft.approve_changes
      end
    end
  end

  def apply_changes
    ActiveRecord::Base.transaction do
      drafts.order(:created_at, :id).each do |draft|
        draft.apply_changes
      end
    end
  end
end
