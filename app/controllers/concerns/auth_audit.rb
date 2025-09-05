module AuthAudit
  private
  def audit!(type, user: nil, meta: {})
    AuthEvent.create!(
      user: user,
      event_type: type,
      ip: request.remote_ip,
      user_agent: request.user_agent.to_s.first(1000),
      metadata: meta.to_json
    ) rescue nil
  end
end
