class AddEmailToOtps < ActiveRecord::Migration[8.0]
  def change
    add_column :otps, :email, :string
    add_index :otps, [:email, :code], name: "index_otps_on_email_and_code"
    
    # Make phone nullable since we now allow email-based OTPs
    change_column_null :otps, :phone, true
    
    # Add check constraint to ensure at least one of phone or email is present
    # Note: This uses raw SQL as Rails doesn't have a built-in way to express this
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE otps ADD CONSTRAINT check_phone_or_email 
          CHECK (phone IS NOT NULL OR email IS NOT NULL);
        SQL
      end
      
      dir.down do
        execute "ALTER TABLE otps DROP CONSTRAINT check_phone_or_email;"
      end
    end
  end
end
