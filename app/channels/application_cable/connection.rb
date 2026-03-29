module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user
      # Anonymous connections allowed for public Turbo Streams (radio pages).
      # Turbo uses signed stream names, so visitors can only subscribe to
      # channels rendered in their HTML.
    end

    private

    def set_current_user
      if (session = Session.find_by(id: cookies.signed[:session_id]))
        self.current_user = session.user
      end
    end
  end
end
