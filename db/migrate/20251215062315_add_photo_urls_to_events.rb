class AddPhotoUrlsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :photo_urls, :json, default: []
  end
end
