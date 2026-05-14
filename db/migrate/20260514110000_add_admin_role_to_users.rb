class AddAdminRoleToUsers < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"

    execute <<~SQL
      UPDATE users
      SET role = 'admin'
      WHERE is_admin = TRUE AND role != 'admin';
    SQL

    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_role
      CHECK (role IN ('user', 'owner', 'admin'))
    SQL
  end

  def down
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"

    execute <<~SQL
      UPDATE users
      SET role = 'user'
      WHERE role = 'admin';
    SQL

    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_role
      CHECK (role IN ('user', 'owner'))
    SQL
  end
end
