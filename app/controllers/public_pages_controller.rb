# frozen_string_literal: true

class PublicPagesController < ApplicationController
  # Public URL for app store / mobile settings privacy policy links.
  def privacy_policy
    document = LegalDocument.find_by(kind: 'privacy_policy')

    if document&.file&.attached?
      redirect_to attachment_url(document.file)
      return
    end

    render_html_page(
      'Privacy Policy',
      'The privacy policy document has not been uploaded yet. Please upload it from the admin legal documents section.'
    )
  end

  # Public support URL for app store / mobile settings support links.
  def support_url
    render_html_page(
      'Support',
      'For support, please sign in to the app and create a support ticket from the Help & Support section.'
    )
  end

  private

  def render_html_page(title, message)
    render(
      plain: <<~HTML,
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{title}</title>
          </head>
          <body>
            <h1>#{title}</h1>
            <p>#{message}</p>
          </body>
        </html>
      HTML
      content_type: 'text/html'
    )
  end
end
