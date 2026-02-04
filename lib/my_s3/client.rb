# frozen_string_literal: true

require 'json'
require 'net/http'
require 'securerandom'
require 'uri'

require_relative 'client/version'

module MyS3
  class Client
    class Error < StandardError; end

    attr_reader :base_url, :api_key

    def initialize(base_url:, api_key:, open_timeout: 10, read_timeout: 60)
      @base_url = normalize_base_url(base_url)
      @api_key = api_key.to_s.strip
      raise Error, 'api_key is required' if @api_key.empty?

      @open_timeout = Integer(open_timeout)
      @read_timeout = Integer(read_timeout)
    end

    # ----------------------
    # High-level API methods
    # ----------------------

    def list(path: '')
      get_json('/list.json', path: path.to_s)
    end

    def create_folder(path:, folder_name:)
      post_json('/create_folder.json', path: path.to_s, folder_name: folder_name.to_s)
    end

    def delete_folder(path:)
      delete_json('/delete_folder.json', path: path.to_s)
    end

    def rename_folder(path:, new_name:)
      post_json('/rename_folder.json', path: path.to_s, new_name: new_name.to_s)
    end

    def delete_file(path:, filename:)
      delete_json('/delete.json', path: path.to_s, filename: filename.to_s)
    end

    def delete_older_than(path:, older_than:)
      post_json('/delete_older_than.json', path: path.to_s, older_than: older_than)
    end

    def get_download_url(path:, filename:)
      post_json('/get_download_url.json', path: path.to_s, filename: filename.to_s)
    end

    def get_public_url(path:, filename:)
      post_json('/get_public_url.json', path: path.to_s, filename: filename.to_s)
    end

    def upload_file(file_path:, path: '', filename: nil, ensure_path: true)
      raise Error, 'file_path is required' if file_path.to_s.strip.empty?
      raise Error, "File not found: #{file_path}" unless File.file?(file_path)

      relative_path = path.to_s
      filename ||= File.basename(file_path)

      ensure_folder_chain(relative_path) if ensure_path

      boundary = "----MyS3Client#{SecureRandom.hex(12)}"
      uri = uri_for('/upload.json')
      request = Net::HTTP::Post.new(uri)
      request['X-API-Key'] = api_key
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = build_my_s3_multipart(boundary, relative_path, filename, file_path)
      response = http_request(uri, request)
      json = parse_json(response.body)
      return json if response.is_a?(Net::HTTPSuccess) && json['success']

      message = json.dig('error', 'message') || response.body
      raise Error, message
    end

    def download_file(path:, filename:, target_path: nil)
      relative = join_relative_path(path, filename)
      uri = URI.join(base_url, relative)
      request = Net::HTTP::Get.new(uri)
      response = http_request(uri, request, include_api_key: false)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Failed to download file: #{response.code} #{response.message}"
      end

      if target_path
        File.binwrite(target_path, response.body)
        target_path
      else
        response.body
      end
    end

    def ensure_folder_chain(path)
      sanitized = normalize_relative_path(path)
      return true if sanitized.empty?

      current = ''
      sanitized.split('/').each do |segment|
        begin
          create_folder(path: current, folder_name: segment)
        rescue Error
          raise unless folder_exists_in_path?(current, segment)
        end
        current = current.empty? ? segment : [current, segment].join('/')
      end

      true
    end

    # ----------------------
    # HTTP helper methods
    # ----------------------

    def get_json(endpoint, params = {})
      uri = uri_for(endpoint, params: params)
      request = Net::HTTP::Get.new(uri)
      request['X-API-Key'] = api_key
      request_json(uri, request)
    end

    def post_json(endpoint, payload = {})
      uri = uri_for(endpoint)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['X-API-Key'] = api_key
      request.body = JSON.generate(payload)
      request_json(uri, request)
    end

    def delete_json(endpoint, payload = {})
      uri = uri_for(endpoint)
      request = Net::HTTP::Delete.new(uri)
      request['Content-Type'] = 'application/json'
      request['X-API-Key'] = api_key
      request.body = JSON.generate(payload)
      request_json(uri, request)
    end

    private

    def request_json(uri, request)
      response = http_request(uri, request)
      json = parse_json(response.body)
      return json if response.is_a?(Net::HTTPSuccess) && json['success']

      message = json.dig('error', 'message') || response.body
      raise Error, message
    end

    def http_request(uri, request, include_api_key: true)
      request['X-API-Key'] = api_key if include_api_key && !request['X-API-Key']
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.request(request)
    rescue Timeout::Error => e
      raise Error, "MyS3 request timed out: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      raise Error, "MyS3 connection failed: #{e.message}"
    end

    def parse_json(body)
      return {} if body.nil? || body.strip.empty?
      JSON.parse(body)
    rescue JSON::ParserError
      raise Error, "Invalid JSON response: #{body}"
    end

    def build_my_s3_multipart(boundary, relative_path, filename, local_path)
      body = []
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"path\"\r\n\r\n"
      body << "#{relative_path}\r\n"
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
      body << "Content-Type: application/octet-stream\r\n\r\n"
      body << File.binread(local_path)
      body << "\r\n--#{boundary}--\r\n"
      body.join
    end

    def uri_for(endpoint, params: nil)
      path = endpoint.to_s.sub(%r{^/+}, '')
      uri = URI.join(base_url, path)
      if params && !params.empty?
        query = URI.encode_www_form(params.transform_values { |v| v.nil? ? '' : v })
        uri.query = query
      end
      uri
    end

    def normalize_base_url(url)
      value = url.to_s.strip
      raise Error, 'base_url is required' if value.empty?
      value.end_with?('/') ? value : "#{value}/"
    end

    def normalize_relative_path(path)
      value = path.to_s.strip
      return '' if value.empty?
      value = value.gsub(%r{^/+}, '').gsub(%r{/+$}, '')
      value
    end

    def join_relative_path(path, filename)
      fragments = [normalize_relative_path(path), filename.to_s]
      fragments.reject!(&:empty?)
      fragments.join('/')
    end

    def folder_exists_in_path?(path, folder_name)
      listing = list(path: path)
      directories = listing['directories'] || []
      directories.any? { |entry| entry['name'].to_s == folder_name.to_s }
    rescue Error
      false
    end
  end
end
