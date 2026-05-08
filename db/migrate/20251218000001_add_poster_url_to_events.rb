class AddPosterUrlToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :poster_url, :string
    add_index :events, :poster_url, where: "poster_url IS NOT NULL"
  end
end

