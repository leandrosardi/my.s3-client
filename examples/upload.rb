#!/usr/bin/env ruby

# Example: upload a file to a MyS3 instance using the ruby client.
#
# Usage:
#   ruby upload.rb /path/to/local-file [remote/path] [remote-filename]
#
# The first argument is mandatory. The second argument defaults to
# `examples/uploads`, and the third argument defaults to the local filename.

require 'pathname'
require_relative '../lib/my_s3/client'
require_relative './config'

abort "Usage: ruby upload.rb /path/to/local-file [remote/path] [remote-filename]" if ARGV.empty?

local_path = Pathname.new(ARGV.shift).expand_path
remote_path = ARGV.shift || 'examples/uploads'
remote_filename = ARGV.shift

unless local_path.file?
	warn "File not found: #{local_path}"
	exit 1
end

remote_filename ||= local_path.basename.to_s

client = MyS3::Client.new(
	base_url: MY_S3_URL,
	api_key: MY_S3_API_KEY
)

begin
	puts "Uploading #{local_path} to #{remote_path}/#{remote_filename}..."
	response = client.upload_file(
		file_path: local_path.to_s,
		path: remote_path,
		filename: remote_filename,
		ensure_path: true
	)
	public_url = client.get_public_url(path: remote_path, filename: remote_filename)['public_url']
	puts "Upload complete!"
	puts "Server response: #{response.inspect}"
	puts "Public URL: #{public_url}" if public_url
rescue MyS3::Client::Error => e
	warn "Upload failed: #{e.message}"
	exit 1
end
