class AddUsernameAndDateOfBirthToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :username, :string
    add_column :users, :date_of_birth, :date
    
    add_index :users, :username, unique: true, where: "username IS NOT NULL"
  end
end
