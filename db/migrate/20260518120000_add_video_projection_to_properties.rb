# frozen_string_literal: true

class AddVideoProjectionToProperties < ActiveRecord::Migration[8.0]
  def change
    add_column :properties, :video_projection, :string, null: false, default: 'flat'

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE properties
          ADD CONSTRAINT check_properties_video_projection
          CHECK (video_projection IN ('flat', 'equirectangular'))
        SQL
      end
      dir.down do
        execute 'ALTER TABLE properties DROP CONSTRAINT IF EXISTS check_properties_video_projection'
      end
    end
  end
end
