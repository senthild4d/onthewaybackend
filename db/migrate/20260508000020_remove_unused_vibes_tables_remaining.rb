class RemoveUnusedVibesTablesRemaining < ActiveRecord::Migration[8.0]
  # Further cleanup: remove payments/wallets/notifications/categories from vibes.
  # DESTRUCTIVE: drops data.
  def up
    drop_tables_cascade!(
      %w[
        notifications
        wallets
        payment_transactions
        payment_methods
        payment_providers
        crypto_wallets
        categories
        categories_groups
        artist_categories
        allergens
      ]
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Dropped unused tables'
  end

  private

  def drop_tables_cascade!(*tables)
    tables.flatten.each do |table|
      execute %(DROP TABLE IF EXISTS "#{table}" CASCADE)
    end
  end
end

