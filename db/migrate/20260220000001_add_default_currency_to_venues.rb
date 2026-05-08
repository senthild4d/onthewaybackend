# frozen_string_literal: true

class AddDefaultCurrencyToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :default_currency, :string, default: 'USD', null: false
  end
end
