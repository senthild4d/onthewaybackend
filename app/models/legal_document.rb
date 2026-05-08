# frozen_string_literal: true

class LegalDocument < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    text/html
    text/plain
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ].freeze

  MAX_FILE_SIZE = 25.megabytes

  enum :kind, {
    community_guidelines: 'community_guidelines',
    terms_of_service: 'terms_of_service',
    privacy_policy: 'privacy_policy'
  }, validate: true

  has_one_attached :file

  validate :validate_file_properties, if: -> { file.attached? }

  def self.kinds_param
    kinds.keys
  end

  def self.normalize_kind(kind_param)
    k = kind_param.to_s
    kinds.key?(k) ? k : nil
  end

  def self.find_or_build_for_kind(kind_param)
    kind = normalize_kind(kind_param)
    return nil unless kind

    find_or_initialize_by(kind: kind)
  end

  private

  def validate_file_properties
    return unless file.blob.present?

    unless ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "must be one of: PDF, HTML, plain text, or Word (#{ALLOWED_CONTENT_TYPES.join(', ')})")
    end

    return unless file.blob.byte_size.present?

    errors.add(:file, "must be at most #{MAX_FILE_SIZE / 1.megabyte} MB") if file.blob.byte_size > MAX_FILE_SIZE
  end
end
