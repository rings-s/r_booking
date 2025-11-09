class Category < ApplicationRecord
  has_many :businesses, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
