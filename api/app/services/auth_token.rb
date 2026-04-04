class AuthToken
  ALGORITHM = "HS256".freeze
  TTL = 12.hours

  class Invalid < StandardError; end

  def self.issue(user, ttl: TTL)
    payload = { sub: user.id, cid: user.company_id, exp: ttl.from_now.to_i }
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: ALGORITHM).first
  rescue JWT::DecodeError => e
    raise Invalid, e.message
  end

  def self.secret
    Rails.application.secret_key_base
  end
end
