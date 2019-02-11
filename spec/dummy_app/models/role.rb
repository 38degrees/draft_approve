require_relative 'draftable'

class Role < Draftable
  validates :name, presence: true
end
