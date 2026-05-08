class MakeUserEmailAndPasswordNullable < ActiveRecord::Migration[8.0]
  def change
    # Make email nullable since users can authenticate with phone
    change_column_null :users, :email, true
    
    # Make password_digest nullable since OTP users don't need password
    change_column_null :users, :password_digest, true
    
    # Add check constraint to ensure at least one of phone or email is present
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE users ADD CONSTRAINT check_user_phone_or_email 
          CHECK (phone IS NOT NULL OR email IS NOT NULL);
        SQL
      end
      
      dir.down do
        execute "ALTER TABLE users DROP CONSTRAINT check_user_phone_or_email;"
      end
    end
  end
end
