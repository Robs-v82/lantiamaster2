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

  it "returns 200 and includes meta.api_version on success" do
    org = Organization.find_or_create_by!(name: "Org API Test Success")
    org.update!(search_level: 6, subscription_started_at: Time.current)

    member = Member.find_or_create_by!(firstname: "Api", lastname1: "Success", lastname2: "User")
    member.update!(organization: org)

    user = User.find_by(mail: "api_success@example.com") || User.create!(mail: "api_success@example.com", password: "Password1")
    user.update!(api_key: "test_key_success", member: member)

    post "/api/v1/members/search",
         params: { name: "juan perez lopez" }.to_json,
         headers: headers_json.merge("X-API-KEY" => user.api_key)

    expect(response).to have_http_status(:ok)
    expect(json.dig("meta", "api_version")).to eq("v1")
    expect(json["status"]).to eq(200)
    expect(json.dig("results", "count")).to be_a(Integer)
    expect(json.dig("results", "members")).to be_a(Array)
  end

  it "returns 429 when org monthly quota is exceeded" do
    org = Organization.find_or_create_by!(name: "Org API Test 429")
    org.update!(search_level: 1, subscription_started_at: Time.current) # plan A (pocos puntos)

    member = Member.find_or_create_by!(firstname: "Api", lastname1: "Limit", lastname2: "User")
    member.update!(organization: org)

    user = User.find_by(mail: "api_limit@example.com") || User.create!(mail: "api_limit@example.com", password: "Password1")
    user.update!(api_key: "test_key_limit", member: member)

    # crea exactamente el límite de queries de la org (plan A = 10)
    limit = 10
    Query.where(user_id: user.id, source: "api").delete_all
    limit.times do
      Query.create!(
        firstname: "X", lastname1: "Y", lastname2: "Z",
        homo_score: 1,
        outcome: [],
        search: 0,
        user: user,
        member: user.member,
        organization: org,
        source: "api",
        status_code: 200,
        success: true,
        request_id: SecureRandom.uuid,
        result_count: 0,
        query_label: "X Y Z"
      )
    end

    post "/api/v1/members/search",
         params: { name: "juan perez lopez" }.to_json,
         headers: headers_json.merge("X-API-KEY" => user.api_key)

    expect(response).to have_http_status(:too_many_requests)
    expect(json.dig("meta", "api_version")).to eq("v1")
    expect(json.dig("errors", 0, "code")).to eq("rate_limit_exceeded")
  end

end