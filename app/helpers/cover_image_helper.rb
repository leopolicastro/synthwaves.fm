module CoverImageHelper
  MUSIC_NOTE_PATH = "M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"

  SIZES = {
    card: {image: "w-full aspect-square object-cover", container: "w-full aspect-square bg-gray-700", icon: "w-12 h-12"},
    card_sm: {image: "w-full aspect-square object-cover", container: "w-full aspect-square bg-gray-700", icon: "w-10 h-10"},
    large: {image: "w-32 h-32 sm:w-48 sm:h-48 object-cover shadow-lg", container: "w-32 h-32 sm:w-48 sm:h-48 bg-gray-700 shadow-lg", icon: "w-16 h-16"},
    medium: {image: "w-24 h-24 sm:w-32 sm:h-32 object-cover", container: "w-24 h-24 sm:w-32 sm:h-32 bg-gray-700", icon: "w-12 h-12"},
    small: {image: "w-16 h-16 object-cover", container: "w-16 h-16 bg-gray-700", icon: "w-8 h-8"},
    tiny: {image: "w-12 h-12 object-cover", container: "w-12 h-12 bg-gray-700", icon: "w-6 h-6"}
  }.freeze

  def cover_image_or_placeholder(attachment, size: :card, rounded: "rounded-lg", lazy: true)
    preset = SIZES.fetch(size)

    if attachment&.attached?
      image_tag attachment, class: "#{preset[:image]} #{rounded}", loading: (lazy ? "lazy" : nil)
    else
      tag.div(class: "#{preset[:container]} #{rounded} flex items-center justify-center") do
        tag.svg(class: "#{preset[:icon]} text-gray-400", fill: "currentColor", viewBox: "0 0 20 20") do
          tag.path(d: MUSIC_NOTE_PATH)
        end
      end
    end
  end
end
