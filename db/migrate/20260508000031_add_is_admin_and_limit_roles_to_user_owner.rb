class AddIsAdminAndLimitRolesToUserOwner < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :is_admin, :boolean, default: false, null: false
    add_index :users, :is_admin

    # Any legacy admin/support users become admin flag users.
    execute <<~SQL
      UPDATE users
      SET is_admin = TRUE
      WHERE role IN ('admin', 'support');
    SQL

    # Drop old role constraint, then normalize roles to user/owner only.
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"

    execute <<~SQL
      UPDATE users
      SET role = 'user'
      WHERE role IS NULL OR role NOT IN ('user','owner');
    SQL

    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_role
      CHECK (role IN ('user', 'owner'))
    SQL
  end

  def down
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"
    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_role
      CHECK (role IN ('user', 'owner', 'support', 'admin'))
    SQL
    remove_index :users, :is_admin if index_exists?(:users, :is_admin)
    remove_column :users, :is_admin if column_exists?(:users, :is_admin)
  end
end

