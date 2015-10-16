json.array!(@crosses) do |cross|
  json.extract! cross, :id, :male_id, :female_id, :link
  json.url cross_url(cross, format: :json)
end
