module Themeable
  extend ActiveSupport::Concern

  THEMES = {
    "synthwave" => {
      label: "Synthwave",
      font_family: "Orbitron",
      font_url: "https://fonts.googleapis.com/css2?family=Orbitron:wght@400;500;600;700;800;900&family=Inter:wght@300;400;500;600;700&display=swap",
      meta_color: "#0a0a1a"
    },
    "reggae" => {
      label: "Reggae",
      font_family: "Righteous",
      font_url: "https://fonts.googleapis.com/css2?family=Righteous&family=Inter:wght@300;400;500;600;700&display=swap",
      meta_color: "#0d1a0d"
    },
    "punk" => {
      label: "Punk",
      font_family: "Rubik Mono One",
      font_url: "https://fonts.googleapis.com/css2?family=Rubik+Mono+One&family=Inter:wght@300;400;500;600;700&display=swap",
      meta_color: "#0a0a0a"
    },
    "jazz" => {
      label: "Jazz",
      font_family: "Playfair Display",
      font_url: "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;500;600;700;800;900&family=Inter:wght@300;400;500;600;700&display=swap",
      meta_color: "#0d0f1a"
    },
    "light" => {
      label: "Light",
      font_family: "Inter",
      font_url: "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap",
      meta_color: "#f8fafc"
    }
  }.freeze

  DEFAULT_THEME = "synthwave"

  included do
    validates :theme, inclusion: {in: THEMES.keys}
  end
end
