# Broadcasts real-time food/bar order updates over ActionCable (split paid, order fully paid).
# Subscribers use OrderChannel with order_id (FoodBarOrder id).
class OrderBroadcaster
  class << self
    def broadcast(order, action, extra = {})
      payload = {
        action: action,
        order_id: order.id,
        order: minimal_order_payload(order)
      }.merge(extra)
      ActionCable.server.broadcast("order_#{order.id}", payload)
    end

    def split_paid(order, split:, amount: nil)
      broadcast(order, 'split_paid', split_id: split.id, amount: amount&.to_f, split: minimal_split_payload(split))
    end

    def order_fully_paid(order)
      broadcast(order, 'order_fully_paid')
    end

    def split_payment_failed(order, split:)
      broadcast(order, 'split_payment_failed', split_id: split.id, split: minimal_split_payload(split))
    end

    private

    def minimal_order_payload(order)
      order.reload
      {
        id: order.id,
        order_number: order.order_number,
        total_amount: order.total_amount.to_f,
        currency: order.currency,
        payment_status: order.payment_status,
        is_split_bill: order.is_split_bill,
        split_count: order.split_count,
        splits: order.bill_splits.map { |s| minimal_split_payload(s) },
        updated_at: order.updated_at.iso8601
      }
    end

    def minimal_split_payload(split)
      {
        id: split.id,
        split_amount: split.split_amount.to_f,
        payment_status: split.payment_status,
        paid_at: split.paid_at&.iso8601,
        user_id: split.user_id,
        participant_name: split.participant_name
      }
    end
  end
end
