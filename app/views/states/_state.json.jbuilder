json.extract! state, :id, :name, :shortname, :code, :population, :created_at, :updated_at
json.url state_url(state, format: :json)
