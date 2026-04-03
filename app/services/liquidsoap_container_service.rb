class LiquidsoapContainerService
  CONTAINER_NAME = "synthwaves_fm-liquidsoap"
  DOCKER_SOCKET = "/var/run/docker.sock"

  def self.restart
    return unless Rails.env.production?

    socket = UNIXSocket.new(DOCKER_SOCKET)
    request = "POST /containers/#{CONTAINER_NAME}/restart HTTP/1.0\r\nHost: localhost\r\n\r\n"
    socket.write(request)
    response = socket.read
    socket.close

    status = response[/HTTP\/\d\.\d (\d+)/, 1].to_i
    unless status == 204
      Rails.logger.warn("Failed to restart Liquidsoap container: HTTP #{status}")
    end
  rescue => e
    Rails.logger.warn("Failed to restart Liquidsoap container: #{e.message}")
  end
end
