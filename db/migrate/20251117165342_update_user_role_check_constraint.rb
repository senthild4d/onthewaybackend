class UpdateUserRoleCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    # Remove old constraint
    remove_check_constraint :users, name: 'check_role'
    
    # Add new constraint with artist role
    add_check_constraint :users, 
      "role IN ('consumer', 'artist', 'venue_manager', 'admin')", 
      name: 'check_role'
  end
  
  def down
    # Remove new constraint
    remove_check_constraint :users, name: 'check_role'
    
    # Restore old constraint
    add_check_constraint :users, 
      "role IN ('consumer', 'venue_manager', 'admin')", 
      name: 'check_role'
  end
end
