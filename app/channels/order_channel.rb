# Real-time updates for a food/bar order: split paid, order fully paid.
# Subscribe with order_id (FoodBarOrder id). Allowed: order owner, any split participant, event venue owner, admin.
class OrderChannel < ApplicationCable::Channel
  def subscribed
    @order = FoodBarOrder.find_by(id: params[:order_id])
    return reject unless @order

    unless can_subscribe?(@order)
      return reject
    end

    stream_from "order_#{@order.id}"
  end

  def unsubscribed
    # cleanup
  end

  private

  def can_subscribe?(order)
    return true if order.user_id == current_user.id
    return true if current_user.role_admin?
    return true if order.event&.venue&.owner_id == current_user.id
    return true if order.bill_splits.exists?(user_id: current_user.id)
    false
  end
end
