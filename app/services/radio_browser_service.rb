class RadioBrowserService
  BASE_URL = "https://de1.api.radio-browser.info/json"

  def search(query, limit: 100)
    get("/stations/byname/#{URI.encode_uri_component(query)}", limit: limit)
  end

  def by_country(code, limit: 100)
    get("/stations/bycountrycodeexact/#{URI.encode_uri_component(code)}", limit: limit, order: "votes", reverse: true)
  end

  def by_tag(tag, limit: 100)
    get("/stations/bytag/#{URI.encode_uri_component(tag)}", limit: limit, order: "votes", reverse: true)
  end

  def top_voted(limit: 100)
    get("/stations/topvote/#{limit}")
  end

  private

  def get(path, **params)
    response = HTTP.headers("User-Agent" => "synthwaves.fm/1.0")
      .timeout(connect: 5, read: 15)
      .get("#{BASE_URL}#{path}", params: params)

    JSON.parse(response.body.to_s)
  end
end
