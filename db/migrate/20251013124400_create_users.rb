class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    # Enable pgcrypto extension for UUID generation
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    
    create_table :users, id: :uuid do |t|
      t.string :email
      t.string :phone, limit: 20
      t.string :password_digest
      t.string :name
      t.string :role, null: false, default: 'consumer'
      t.string :status, null: false, default: 'active'
      t.jsonb :preferences, default: {}

      t.timestamps
    end

    # Indexes
    add_index :users, :email, unique: true
    add_index :users, :phone, unique: true, where: "phone IS NOT NULL"
    add_index :users, :role
    add_index :users, :status
    add_index :users, :created_at

    # Check constraints
    execute <<-SQL
      ALTER TABLE users ADD CONSTRAINT check_role 
        CHECK (role IN ('consumer', 'venue_manager', 'admin'));
      
      ALTER TABLE users ADD CONSTRAINT check_status 
        CHECK (status IN ('active', 'disabled'));
      
      ALTER TABLE users ADD CONSTRAINT check_email_format 
        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$');
    SQL
  end
end
