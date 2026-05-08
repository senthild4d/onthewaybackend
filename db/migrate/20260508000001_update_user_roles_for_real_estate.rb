class UpdateUserRolesForRealEstate < ActiveRecord::Migration[8.0]
  def up
    # Map legacy roles into the 4 roles we keep:
    # - consumer/artist/brand -> user
    # - venue_manager        -> owner
    execute <<~SQL
      UPDATE users
      SET role = 'user'
      WHERE role IN ('consumer', 'artist', 'brand');
    SQL

    execute <<~SQL
      UPDATE users
      SET role = 'owner'
      WHERE role IN ('venue_manager');
    SQL

    # Drop and recreate role check constraint to only allow new roles.
    # Name in schema is "check_role".
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"

    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_role
      CHECK (role IN ('user', 'owner', 'support', 'admin'))
    SQL
  end

  def down
    # Best-effort rollback: restore broader role set.
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"

    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_role
      CHECK (role IN ('consumer', 'artist', 'venue_manager', 'admin', 'brand', 'support'))
    SQL

    # Keep data as-is; don't attempt to map back automatically.
  end
end

