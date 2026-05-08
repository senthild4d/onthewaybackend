# frozen_string_literal: true

module Api
  module V1
    class LegalDocumentsController < ApplicationController
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
