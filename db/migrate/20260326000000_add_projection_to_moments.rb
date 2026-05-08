# frozen_string_literal: true

class AddProjectionToMoments < ActiveRecord::Migration[8.0]
  def change
    add_column :moments, :projection, :string, null: false, default: 'flat'
    add_check_constraint :moments, "projection IN ('flat', 'equirectangular')", name: 'check_moments_projection'
  end
end
