class UpdateUserRolesForRealEstate < ActiveRecord::Migration[8.0]
  def up
    # IMPORTANT: Drop the old constraint first.
    # Old vibes roles constraint doesn't allow the new 'user'/'owner' values,
    # so updating rows before dropping it will fail.
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_role"

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

    # Normalize any unexpected legacy roles (safety net).
    execute <<~SQL
      UPDATE users
      SET role = 'user'
      WHERE role IS NULL
         OR role NOT IN ('user', 'owner', 'support', 'admin');
    SQL

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

