class LanguageDetectorService
  LRC_TIMESTAMP = /\[\d{2}:\d{2}[.:]\d{2,3}\]\s*/

  LANGUAGE_NAME_TO_CODE = {
    english: "en", french: "fr", german: "de", spanish: "es",
    portuguese: "pt", italian: "it", dutch: "nl", swedish: "sv",
    norwegian: "no", danish: "da", finnish: "fi", polish: "pl",
    russian: "ru", arabic: "ar", turkish: "tr", hungarian: "hu",
    czech: "cs", romanian: "ro", greek: "el", japanese: "ja",
    korean: "ko", chinese: "zh", thai: "th", vietnamese: "vi",
    indonesian: "id", hindi: "hi", farsi: "fa", hebrew: "he",
    pinyin: "zh", sanskrit: "sa"
  }.freeze

  STOREFRONT_TO_LANGUAGE = {
    "jp" => "ja", "kr" => "ko", "cn" => "zh", "tw" => "zh",
    "br" => "pt", "pt" => "pt", "mx" => "es", "es" => "es",
    "ar" => "es", "cl" => "es", "co" => "es", "pe" => "es",
    "fr" => "fr", "de" => "de", "it" => "it", "nl" => "nl",
    "ru" => "ru", "se" => "sv", "no" => "nb", "dk" => "da",
    "fi" => "fi", "pl" => "pl", "tr" => "tr", "in" => "hi",
    "th" => "th", "id" => "id", "vn" => "vi",
    "us" => "en", "gb" => "en", "au" => "en", "ca" => "en",
    "ie" => "en", "nz" => "en", "za" => "en"
  }.freeze

  def self.call(track)
    new(track).call
  end

  def initialize(track)
    @track = track
  end

  def call
    detect_from_lyrics || detect_from_storefront
  end

  private

  def detect_from_lyrics
    return nil if @track.lyrics.blank?

    plain_text = @track.lyrics.gsub(LRC_TIMESTAMP, "").strip
    return nil if plain_text.length < 20

    wl = WhatLanguage.new(:all)
    detected = wl.language(plain_text)
    detected ? LANGUAGE_NAME_TO_CODE[detected] : nil
  rescue => e
    Rails.logger.warn("LanguageDetectorService: lyrics detection failed for track #{@track.id}: #{e.message}")
    nil
  end

  def detect_from_storefront
    storefront = @track.artist.apple_music_storefront
    return nil if storefront.blank?

    STOREFRONT_TO_LANGUAGE[storefront.downcase]
  end
end
