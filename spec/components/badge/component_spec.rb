require "rails_helper"

RSpec.describe Badge::Component, type: :component do
  include ViewComponent::TestHelpers

  it "renders the text" do
    html = render_inline(described_class.new(text: "Rock"))
    expect(html.text.strip).to include("Rock")
  end

  it "renders default variant" do
    html = render_inline(described_class.new(text: "Tag"))
    expect(html.at_css("span")["class"]).to include("bg-gray-700", "text-gray-300")
  end

  it "renders genre variant" do
    html = render_inline(described_class.new(text: "Rock", variant: :genre))
    expect(html.at_css("span")["class"]).to include("bg-neon-cyan/20", "text-neon-cyan")
  end

  it "renders mood variant" do
    html = render_inline(described_class.new(text: "Chill", variant: :mood))
    expect(html.at_css("span")["class"]).to include("bg-neon-purple/20", "text-neon-purple")
  end

  it "renders primary variant" do
    html = render_inline(described_class.new(text: "Hot", variant: :primary))
    expect(html.at_css("span")["class"]).to include("bg-neon-pink/20", "text-neon-pink")
  end

  it "renders danger variant" do
    html = render_inline(described_class.new(text: "Error", variant: :danger))
    expect(html.at_css("span")["class"]).to include("bg-red-500/20", "text-red-400")
  end

  it "renders small size" do
    html = render_inline(described_class.new(text: "Sm", size: :small))
    expect(html.at_css("span")["class"]).to include("px-1.5")
  end

  it "renders medium size by default" do
    html = render_inline(described_class.new(text: "Md"))
    expect(html.at_css("span")["class"]).to include("px-2")
  end

  it "renders large size" do
    html = render_inline(described_class.new(text: "Lg", size: :large))
    expect(html.at_css("span")["class"]).to include("px-3", "text-sm")
  end

  it "renders content block when dismissible" do
    html = render_inline(described_class.new(text: "Removable", dismissible: true)) do
      "<button>X</button>".html_safe
    end
    expect(html.at_css("button")).to be_present
  end

  it "does not render content block when not dismissible" do
    html = render_inline(described_class.new(text: "Static")) do
      "<button>X</button>".html_safe
    end
    expect(html.at_css("button")).to be_nil
  end

  it "does not render when text is blank" do
    html = render_inline(described_class.new(text: ""))
    expect(html.to_html.strip).to eq("")
  end

  it "does not render when text is nil" do
    html = render_inline(described_class.new(text: nil))
    expect(html.to_html.strip).to eq("")
  end

  it "has rounded-full class" do
    html = render_inline(described_class.new(text: "Pill"))
    expect(html.at_css("span")["class"]).to include("rounded-full")
  end
end
