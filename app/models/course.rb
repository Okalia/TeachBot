class Course < ApplicationRecord
  belongs_to :author, class_name: 'User', touch: true
  has_and_belongs_to_many :subscribers, class_name: 'User'
  has_many :lessons, dependent: :destroy

  after_create :add_author_as_participant

  validates :title, presence: true, length: {minimum: 6, maximum: 30}
  validates :description, presence: true, length: {minimum: 6, maximum: 255}
  validates :public, inclusion: { in: [true, false] }

  before_destroy :clean_all_courses_cache
  after_update_commit :clean_all_courses_cache

  private

  def add_author_as_participant
    self.subscribers << self.author
  end

  def clean_all_courses_cache
    Rails.cache.delete('course/index/all')
  end

end
