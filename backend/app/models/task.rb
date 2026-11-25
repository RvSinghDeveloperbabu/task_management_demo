class Task < ApplicationRecord
  STATUSES = %w[pending processing done].freeze

  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }

  def done?
    status == "done"
  end
end
