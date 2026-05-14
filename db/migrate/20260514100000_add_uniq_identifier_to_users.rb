class AddUniqIdentifierToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :uniq_identifier, :string
    add_index :users, :uniq_identifier, unique: true

    say_with_time 'Backfilling uniq_identifier for existing users' do
      User.reset_column_information
      User.find_each do |user|
        next if user.uniq_identifier.present?

        user.update_column(:uniq_identifier, UserIdentifierGenerator.generate)
      end
    end

    change_column_null :users, :uniq_identifier, false
  end

  def down
    remove_index :users, :uniq_identifier
    remove_column :users, :uniq_identifier
  end
end
