class AddCollaboratorToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :collaborator_type, :string
    add_column :events, :collaborator_id, :uuid
    add_index  :events, [:collaborator_type, :collaborator_id]
  end
end

