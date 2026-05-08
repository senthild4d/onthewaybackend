# frozen_string_literal: true

class AddBrandToUserRoleCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :users, name: 'check_role'

    add_check_constraint :users,
      "role IN ('consumer', 'artist', 'venue_manager', 'admin', 'brand')",
      name: 'check_role'
  end

  def down
    remove_check_constraint :users, name: 'check_role'

    add_check_constraint :users,
      "role IN ('consumer', 'artist', 'venue_manager', 'admin')",
      name: 'check_role'
  end
end
