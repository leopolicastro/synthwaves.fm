class AdminConstraint
  def matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false unless session_id

    session = Session.find_by(id: session_id)
    session&.user&.admin?
  end
end
