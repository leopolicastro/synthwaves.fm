FactoryBot.define do
  factory :favorite do
    user
    association :favorable, factory: :track
  end
end
