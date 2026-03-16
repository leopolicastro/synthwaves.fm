require "rails_helper"

RSpec.describe "InternetRadioStations", type: :request do
  let(:user) { create(:user) }

  before do
    login_user(user)
    Flipper.enable(:internet_radio, user)
  end

  describe "GET /internet-radio" do
    it "returns success" do
      get internet_radio_stations_path
      expect(response).to have_http_status(:ok)
    end

    it "lists active stations" do
      create(:internet_radio_station, name: "Cool Jazz FM")
      create(:internet_radio_station, :inactive, name: "Dead Station")

      get internet_radio_stations_path
      expect(response.body).to include("Cool Jazz FM")
      expect(response.body).not_to include("Dead Station")
    end

    it "searches stations by name" do
      create(:internet_radio_station, name: "Rock Radio")
      create(:internet_radio_station, name: "Jazz FM")

      get internet_radio_stations_path, params: {q: "Rock"}
      expect(response.body).to include("Rock Radio")
      expect(response.body).not_to include("Jazz FM")
    end

    it "filters by country code" do
      create(:internet_radio_station, name: "US Station", country_code: "US")
      create(:internet_radio_station, name: "DE Station", country_code: "DE")

      get internet_radio_stations_path, params: {country: "US"}
      expect(response.body).to include("US Station")
      expect(response.body).not_to include("DE Station")
    end

    it "filters by category" do
      category = create(:internet_radio_category, slug: "rock")
      create(:internet_radio_station, name: "Rock Station", internet_radio_category: category)
      create(:internet_radio_station, name: "Other Station")

      get internet_radio_stations_path, params: {category: "rock"}
      expect(response.body).to include("Rock Station")
      expect(response.body).not_to include("Other Station")
    end

    it "sorts by popular" do
      create(:internet_radio_station, name: "Unpopular", votes: 1)
      create(:internet_radio_station, name: "Popular", votes: 1000)

      get internet_radio_stations_path, params: {sort: "popular"}
      expect(response.body.index("Popular")).to be < response.body.index("Unpopular")
    end

    it "paginates results" do
      create_list(:internet_radio_station, 30)

      get internet_radio_stations_path
      expect(response.body).to include("nav")
    end

    it "filters by favorites" do
      favorited = create(:internet_radio_station, name: "My Fav Station")
      create(:internet_radio_station, name: "Other Station")
      create(:favorite, user: user, favorable: favorited)

      get internet_radio_stations_path, params: {favorites: "1"}
      expect(response.body).to include("My Fav Station")
      expect(response.body).not_to include("Other Station")
    end

    it "redirects when feature is disabled" do
      Flipper.disable(:internet_radio, user)
      get internet_radio_stations_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /internet-radio/:id" do
    it "returns success" do
      station = create(:internet_radio_station)
      get internet_radio_station_path(station)
      expect(response).to have_http_status(:ok)
    end

    it "shows station details" do
      station = create(:internet_radio_station, name: "My Radio", country: "United States", codec: "MP3", bitrate: 192)
      get internet_radio_station_path(station)
      expect(response.body).to include("My Radio")
      expect(response.body).to include("United States")
      expect(response.body).to include("MP3")
    end
  end

  describe "GET /internet-radio/:id/edit" do
    it "returns success" do
      station = create(:internet_radio_station)
      get edit_internet_radio_station_path(station)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /internet-radio/:id" do
    it "updates the station" do
      station = create(:internet_radio_station, name: "Old Name")
      patch internet_radio_station_path(station), params: {internet_radio_station: {name: "New Name"}}
      expect(response).to redirect_to(internet_radio_station_path(station))
      expect(station.reload.name).to eq("New Name")
    end

    it "renders edit on validation error" do
      station = create(:internet_radio_station)
      patch internet_radio_station_path(station), params: {internet_radio_station: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /internet-radio/:id" do
    it "deletes the station" do
      station = create(:internet_radio_station)
      expect {
        delete internet_radio_station_path(station)
      }.to change(InternetRadioStation, :count).by(-1)
      expect(response).to redirect_to(internet_radio_stations_path)
    end
  end

  describe "POST /internet-radio/import" do
    before do
      stub_request(:get, /de1\.api\.radio-browser\.info/)
        .to_return(body: [
          {
            "stationuuid" => "abc-123",
            "name" => "Test Radio",
            "url_resolved" => "https://stream.example.com/radio.mp3",
            "url" => "https://stream.example.com/radio.mp3",
            "homepage" => "",
            "favicon" => "",
            "country" => "United States",
            "countrycode" => "US",
            "language" => "english",
            "tags" => "rock",
            "codec" => "MP3",
            "bitrate" => 128,
            "votes" => 100
          }
        ].to_json, headers: {"Content-Type" => "application/json"})
    end

    it "imports stations by country code" do
      expect {
        post import_internet_radio_stations_path, params: {country_code: "US"}
      }.to change(InternetRadioStation, :count).by(1)

      expect(response).to redirect_to(internet_radio_stations_path)
      follow_redirect!
      expect(response.body).to include("Imported 1 stations")
    end

    it "imports stations by tag" do
      expect {
        post import_internet_radio_stations_path, params: {tag: "rock"}
      }.to change(InternetRadioStation, :count).by(1)
    end

    it "requires country code or tag" do
      post import_internet_radio_stations_path
      expect(response).to redirect_to(internet_radio_stations_path)
      follow_redirect!
      expect(response.body).to include("Please provide a country code or tag")
    end
  end

  describe "POST /internet-radio/import_url" do
    it "imports a station from a URL with a stream" do
      html = <<~HTML
        <html>
          <head><title>Cool FM</title></head>
          <body><audio><source src="https://stream.example.com/live.mp3"></audio></body>
        </html>
      HTML

      stub_request(:get, "https://coolfm.com/")
        .to_return(headers: {"Content-Type" => "text/html"}, body: html)

      expect {
        post import_url_internet_radio_stations_path, params: {url: "https://coolfm.com/"}
      }.to change(InternetRadioStation, :count).by(1)

      station = InternetRadioStation.last
      expect(response).to redirect_to(internet_radio_station_path(station))
    end

    it "requires a URL" do
      post import_url_internet_radio_stations_path, params: {url: ""}
      expect(response).to redirect_to(internet_radio_stations_path)
      follow_redirect!
      expect(response.body).to include("Please provide a URL")
    end

    it "shows error when no stream found" do
      html = "<html><head><title></title></head><body></body></html>"

      stub_request(:get, "https://noradio.example.com/")
        .to_return(headers: {"Content-Type" => "text/html"}, body: html)

      stub_request(:get, /de1\.api\.radio-browser\.info/)
        .to_return(body: "[]", headers: {"Content-Type" => "application/json"})

      post import_url_internet_radio_stations_path, params: {url: "https://noradio.example.com/"}
      expect(response).to redirect_to(internet_radio_stations_path)
      follow_redirect!
      expect(response.body).to include("Could not find a stream URL")
    end
  end
end
