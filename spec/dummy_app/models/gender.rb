require_relative 'draftable'

class Gender < Draftable
  validates :name, presence: true
end
