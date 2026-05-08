# frozen_string_literal: true

class CreateLegalDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :legal_documents, id: :uuid do |t|
      t.string :kind, null: false

      t.timestamps
    end

    add_index :legal_documents, :kind, unique: true
  end
end
