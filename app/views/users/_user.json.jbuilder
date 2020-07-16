json.extract! user, :id, :firstname, :lastname1, :lastname2, :mail, :mobile_phone, :other_phone, :created_at, :updated_at
json.url user_url(user, format: :json)
