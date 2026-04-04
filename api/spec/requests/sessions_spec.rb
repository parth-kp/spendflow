require "rails_helper"

RSpec.describe "Sessions" do
  let!(:user) { create(:user, email: "pat@example.com", password: "s3cretpass") }

  it "issues a token for valid credentials" do
    post "/api/v1/session", params: { email: "PAT@example.com", password: "s3cretpass" }

    expect(response).to have_http_status(:created)
    expect(json["token"]).to be_present
    expect(json.dig("user", "email")).to eq("pat@example.com")
  end

  it "rejects a bad password" do
    post "/api/v1/session", params: { email: "pat@example.com", password: "nope" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects deactivated users" do
    user.update!(active: false)
    post "/api/v1/session", params: { email: "pat@example.com", password: "s3cretpass" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the current user for a valid token" do
    get "/api/v1/session", headers: auth_headers(user)
    expect(json.dig("user", "id")).to eq(user.id)
  end

  it "rejects an expired token" do
    token = AuthToken.issue(user, ttl: -1.minute)
    get "/api/v1/session", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:unauthorized)
  end
end
