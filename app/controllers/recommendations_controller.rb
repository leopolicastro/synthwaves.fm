class RecommendationsController < ApplicationController
  def show
    @chat = Chat.create!(model: default_model)
    prompt = AiDjService.call(user: Current.user)
    ChatResponseJob.perform_later(@chat.id, prompt)
  end

  private

  def default_model
    Model.find_by(model_id: "gpt-4o-mini") || Model.first
  end
end
