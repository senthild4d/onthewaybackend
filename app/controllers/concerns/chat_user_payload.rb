# frozen_string_literal: true

# Matches UsersController#user_response role logic for 1:1 chat JSON.
module ChatUserPayload
  extend ActiveSupport::Concern

  private

  def chat_user_role(user)
    pr_partnership = user.venue_pr_partnerships&.active&.last
    pr_partnership&.role || user.role
  end

  def chat_user_json(user)
    {
      id: user.id,
      name: user.name,
      username: user.username,
      role: chat_user_role(user)
    }
  end
end
