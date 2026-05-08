class PropertyViewing < ApplicationRecord
  belongs_to :property
  belongs_to :user
  belongs_to :handled_by, class_name: 'User', optional: true

  enum :status, {
    requested: 'requested',
    confirmed: 'confirmed',
    cancelled: 'cancelled',
    completed: 'completed'
  }, prefix: true

  validates :status, inclusion: { in: statuses.keys }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_phone, format: { with: /\A\+?\d+\z/ }, allow_blank: true
  validate :contact_present

  scope :recent, -> { order(created_at: :desc) }

  def mark_handled!(by:)
    update!(handled_by: by, handled_at: Time.current)
  end

  private

  def contact_present
    if contact_phone.blank? && contact_email.blank?
      errors.add(:base, 'Either contact_phone or contact_email is required')
    end
  end
end

