class AddBookingIdToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :booking_id, :uuid

    remove_index :chats, name: "index_chats_users_unique"
    add_index :chats, [:user1_id, :user2_id, :booking_id], unique: true, name: "index_chats_users_booking_unique"

    add_foreign_key :chats, :bookings, column: :booking_id, on_delete: :nullify
  end
end

