# frozen_string_literal: true

require_relative 'lib/my_s3/client/version'

Gem::Specification.new do |spec|
  spec.name          = 'my-s3-client'
  spec.version       = MyS3::Client::VERSION
  spec.authors       = ['Leandro D. Sardi']
  spec.email         = ['leandro@massprospecting.com']

  spec.summary       = 'Ruby client for the My.S3 object storage service.'
  spec.description   = 'Simple, dependency-light client for talking to a My.S3 server via its JSON and multipart HTTP API.'
  spec.homepage      = 'https://github.com/leandrosardi/my.s3'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/leandrosardi/my.s3-client'
  spec.metadata['changelog_uri'] = spec.metadata['source_code_uri']

  spec.files         = Dir.glob('lib/**/*') + %w[README.md LICENSE]
  spec.require_paths = ['lib']

  spec.add_dependency 'net-http', '>= 0.2.0'
  spec.add_dependency 'json', '>= 2.6'
  spec.add_dependency 'uri', '>= 0.11'

  spec.required_ruby_version = '>= 3.0'
end
