module DraftApprove
  class DraftTransaction < ActiveRecord::Base
    has_many :drafts
  end
end
