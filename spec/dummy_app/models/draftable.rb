class Draftable < ActiveRecord::Base
  self.abstract_class = true

  acts_as_draftable
end
