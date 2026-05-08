# frozen_string_literal: true

class VenuePrOneMasterManyJuniors < ActiveRecord::Migration[7.1]
  def up
    # Remove old constraint: one active PR per venue
    remove_index :venue_pr_partnerships,
                name: 'index_venue_pr_partnerships_active_venue',
                if_exists: true

    # One active master_pr per venue
    add_index :venue_pr_partnerships,
              :venue_id,
              unique: true,
              where: "status = 'active' AND role = 'master_pr'",
              name: 'index_venue_pr_partnerships_active_master_per_venue'

    # Same user cannot have multiple active partnerships with the same venue
    add_index :venue_pr_partnerships,
              %i[venue_id user_id],
              unique: true,
              where: "status = 'active'",
              name: 'index_venue_pr_partnerships_active_venue_user'
  end

  def down
    remove_index :venue_pr_partnerships,
                name: 'index_venue_pr_partnerships_active_master_per_venue',
                if_exists: true
    remove_index :venue_pr_partnerships,
                name: 'index_venue_pr_partnerships_active_venue_user',
                if_exists: true

    add_index :venue_pr_partnerships,
              :venue_id,
              unique: true,
              where: "status = 'active'",
              name: 'index_venue_pr_partnerships_active_venue'
  end
end
