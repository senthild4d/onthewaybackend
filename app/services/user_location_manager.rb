class UserLocationManager
  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      super('Location validation failed')
      @errors = errors
    end
  end

  def initialize(user)
    @user = user
  end

  def record_device_location(params)
    snapshot = LocationSnapshot.build_from_params(params, source: 'device')
    persist_snapshot!(snapshot)
  end

  def record_manual_location(params)
    snapshot = LocationSnapshot.build_from_params(params, source: 'manual')
    persist_snapshot!(snapshot)
  end

  def reset!
    snapshot = LocationSnapshot.new(source: 'device_pending', recorded_at: Time.current)
    persist_snapshot!(snapshot)
  end

  def current_location
    user.current_location_snapshot
  end

  private

  attr_reader :user

  def persist_snapshot!(snapshot)
    raise ValidationError.new(snapshot.errors.full_messages) unless snapshot.valid?

    user.set_current_location!(snapshot)
    snapshot
  end
end

