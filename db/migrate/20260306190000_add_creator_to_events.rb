class AddCreatorToEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :events, :creator, type: :uuid, foreign_key: { to_table: :users }, null: true
  end
end

