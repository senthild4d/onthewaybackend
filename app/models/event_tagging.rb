# frozen_string_literal: true

class EventTagging < ApplicationRecord
  belongs_to :event
  belongs_to :event_tag

  validates :event_id, uniqueness: { scope: :event_tag_id }
end

