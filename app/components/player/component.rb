module Player
  class Component < ViewComponent::Base
    def render?
      helpers.authenticated?
    end
  end
end
