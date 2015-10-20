json.array!(@flies) do |fly|
  json.extract! fly, :id, :chr1, :chr2, :chr3, :chr4, :cross_id
  json.url fly_url(fly, format: :json)
end
