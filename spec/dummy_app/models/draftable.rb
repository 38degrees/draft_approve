class Draftable < ActiveRecord::Base
  self.abstract_class = true

  has_drafts
end
