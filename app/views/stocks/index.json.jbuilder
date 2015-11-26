json.array!(@stocks) do |stock|
  json.extract! stock, :id, :number, :name, :fly_id, :lab_id, :user_id, :comment, :date_established, :room_id, :reference, :received_from
  json.url stock_url(stock, format: :json)
end
