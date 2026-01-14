require "rails_helper"

RSpec.describe "API V1 Members Search", type: :request do
  let(:headers_json) { { "CONTENT_TYPE" => "application/json" } }

  def json
    JSON.parse(response.body)
  end

  it "returns 401 when api key is missing" do
    post "/api/v1/members/search", params: { name: "juan perez lopez" }.to_json, headers: headers_json
    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("meta", "api_version")).to eq("v1")
    expect(json.dig("errors", 0, "code")).to eq("unauthorized")
  end

  it "returns 422 when name is too short" do
    user = User.find_by(api_key: "test_key") || User.create!(mail: "api_test@example.com", password: "Password1", api_key: "test_key")
    member = Member.find_or_create_by!(firstname: "Api", lastname1: "Test", lastname2: "User")
    user.update!(member: member)
    org = Organization.find_or_create_by!(name: "Org API Test")
    member.update!(organization: org)
    org.update!(search_level: 6, subscription_started_at: Time.current)

    post "/api/v1/members/search",
         params: { name: "abc" }.to_json,
         headers: headers_json.merge("X-API-KEY" => user.api_key)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json.dig("meta", "api_version")).to eq("v1")
    expect(json.dig("errors", 0, "code")).to eq("invalid_request")
  end
end