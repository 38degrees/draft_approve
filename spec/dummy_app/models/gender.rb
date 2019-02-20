require_relative 'draftable'

class Gender < Draftable
  validates :name, presence: true

  has_many :people
end
