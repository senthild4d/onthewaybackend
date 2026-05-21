# frozen_string_literal: true

module Api
  module V1
    class LegalDocumentsController < ApplicationController
      before_action :require_authentication!, only: [:upload]
      before_action :require_admin!, only: [:upload]

      # GET /api/v1/legal_documents
      def index
        items = LegalDocument.kinds.keys.map do |kind|
          legal_document_response(LegalDocument.find_by(kind: kind), kind: kind)
        end

        api_success(data: { legal_documents: items }, status: :ok)
      end

      # GET /api/v1/legal_documents/:kind
      def show
        kind = LegalDocument.normalize_kind(params[:kind])
        unless kind
          api_error(message: 'Invalid document type', status: :bad_request)
          return
        end

        record = LegalDocument.find_by(kind: kind)
        api_success(
          data: { legal_document: legal_document_response(record, kind: kind) },
          status: :ok
        )
      end

      # POST /api/v1/legal_documents
      #
      # multipart/form-data:
      # - kind: community_guidelines | terms_of_service | privacy_policy
      # - file: PDF/HTML/TXT/DOC/DOCX (also accepts field name "document")
      def upload
        kind = LegalDocument.normalize_kind(params[:kind] || params[:document_type] || params[:type])
        unless kind
          api_error(message: "Invalid document type. Use: #{LegalDocument.kinds.keys.join(', ')}", status: :bad_request)
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
            data: { legal_document: legal_document_response(legal_document, kind: kind) },
            message: 'Document uploaded successfully',
            status: :ok
          )
        else
          api_validation_error(errors: legal_document.errors.full_messages)
        end
      end

      private

      def legal_document_response(record, kind:)
        base = {
          kind: kind,
          uploaded: false,
          url: nil,
          filename: nil,
          content_type: nil,
          byte_size: nil,
          updated_at: nil
        }

        return base unless record&.file&.attached?

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
