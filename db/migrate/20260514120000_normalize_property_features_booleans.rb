class NormalizePropertyFeaturesBooleans < ActiveRecord::Migration[8.0]
  def up
    say_with_time 'Normalizing property feature values to booleans' do
      Property.find_each do |property|
        normalized = Property.normalize_features_hash(property.features)
        next if normalized == property.features

        property.update_column(:features, normalized)
      end
    end
  end

  def down
    # no-op: cannot reliably restore original string values
  end
end
