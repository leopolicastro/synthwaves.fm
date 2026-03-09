FactoryBot.define do
  factory :folder do
    user
    sequence(:name) { |n| "Folder #{n}" }
  end
end
