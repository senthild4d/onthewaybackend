# frozen_string_literal: true

class AddSupportRoleAndCountriesToUsers < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :users, name: 'check_role'

    add_check_constraint :users,
      "role IN ('consumer', 'artist', 'venue_manager', 'admin', 'brand', 'support')",
      name: 'check_role'

    add_column :users, :support_countries, :jsonb, default: [], null: false, comment: 'Country codes (e.g. UK, US) this support user can moderate'
  end

  def down
    remove_column :users, :support_countries, if_exists: true

    remove_check_constraint :users, name: 'check_role'

    add_check_constraint :users,
      "role IN ('consumer', 'artist', 'venue_manager', 'admin', 'brand')",
      name: 'check_role'
  end
end
