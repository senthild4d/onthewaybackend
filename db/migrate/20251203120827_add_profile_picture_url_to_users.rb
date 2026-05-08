class AddProfilePictureUrlToUsers < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:users, :profile_picture_url)
      add_column :users, :profile_picture_url, :string
    end
  end
end

