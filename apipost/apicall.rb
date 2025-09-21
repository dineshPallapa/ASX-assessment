require 'json'
require 'net/http'
require 'uri'
require 'logger'
require 'openssl'

# Logger setup
logger = Logger.new($stdout)
logger.level = Logger::DEBUG

# Configurable variables for stretch goal
INPUT_FILE = 'example.json'
BASE_URL = 'https://example.com'  # Change to target service base URL
ENDPOINT = '/service/generate'

begin
  # Step 1: Read and validate JSON from file
  raw_content = File.read(INPUT_FILE)
  data = JSON.parse(raw_content)
  logger.info("Successfully parsed JSON from #{INPUT_FILE}")

  # Step 2: Filter objects where private == false
  filtered_data = data.select { |key, obj| obj['private'] == false }
  logger.info("Filtered data to include only objects with private: false")

  # Step 3 & 4: Make HTTPS POST request with filtered JSON
  uri = URI.join(BASE_URL, ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  request = Net::HTTP::Post.new(uri.request_uri)
  request['Content-Type'] = 'application/json'
  request.body = filtered_data.to_json

  logger.info("Sending POST request to #{uri}")
  response = http.request(request)

  # Check response success
  unless response.is_a?(Net::HTTPSuccess)
    logger.error("HTTP request failed with code #{response.code}: #{response.message}")
    exit 1
  end

  # Step 5: Parse response JSON and print keys with valid: true
  response_data = JSON.parse(response.body)
  logger.info("Received response with #{response_data.size} entries")

  response_data.each do |key, obj|
    if obj.is_a?(Hash) && obj['valid'] == true
      puts key
    end
  end

rescue JSON::ParserError => e
  logger.fatal("JSON parsing error: #{e.message}")
  exit 1
rescue Errno::ENOENT => e
  logger.fatal("File not found: #{e.message}")
  exit 1
rescue StandardError => e
  logger.fatal("Unexpected error: #{e.class} - #{e.message}")
  logger.debug(e.backtrace.join("\n"))
  exit 1
end
