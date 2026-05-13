# frozen_string_literal: true

module Api
  module V1
    module Admin
      class LegalDocumentsController < ApplicationController
        before_action :require_authentication!
        before_action :require_admin!

        # POST /api/v1/admin/legal_documents/:kind/upload
        #
        # multipart/form-data: field "file" (also accepts "document")
        def upload
          kind = LegalDocument.normalize_kind(params[:kind])
          unless kind
            api_error(message: 'Invalid document type. Use: community_guidelines, terms_of_service, privacy_policy', status: :bad_request)
            return
          end

          upload = params[:file] || params[:document]
          if upload.blank?
            api_error(message: 'File is required (multipart field "file" or "document")', status: :bad_request)
            return
          end

          if upload.is_a?(String)
            api_error(message: 'File must be uploaded as multipart binary data, not a path string', status: :bad_request)
            return
          end

          legal_document = LegalDocument.find_or_initialize_by(kind: kind)
          legal_document.file.attach(upload)

          if legal_document.save
            api_success(
              data: { legal_document: legal_document_response(legal_document) },
              message: 'Document uploaded successfully',
              status: :ok
            )
          else
            api_validation_error(errors: legal_document.errors.full_messages)
          end
        end

        # GET /api/v1/admin/legal_documents
        def index
          items = LegalDocument.kinds.keys.map do |k|
            legal_document_response(LegalDocument.find_by(kind: k), kind: k)
          end

          api_success(data: { legal_documents: items }, status: :ok)
        end

        private

        def legal_document_response(record, kind: nil)
          k = kind || record&.kind
          base = {
            kind: k,
            uploaded: false,
            url: nil,
            filename: nil,
            content_type: nil,
            byte_size: nil,
            updated_at: nil
          }

          return base if record.blank? || !record.file.attached?

          base.merge(
            uploaded: true,
            url: file_url(record.file),
            filename: record.file.filename.to_s,
            content_type: record.file.blob&.content_type,
            byte_size: record.file.blob&.byte_size,
            updated_at: record.updated_at&.iso8601
          )
        end

        def file_url(attachment)
          Rails.application.routes.url_helpers.rails_blob_url(attachment, host: request.base_url)
        end
      end
    end
  end
end
