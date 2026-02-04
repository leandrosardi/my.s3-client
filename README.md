# My.S3 Client

Ruby client library for [My.S3](https://github.com/leandrosardi/my.s3) — the filesystem-backed object store. The gem adds ergonomic helpers around the official HTTP API and keeps dependencies minimal so it can run anywhere Ruby and Net::HTTP are available.

## Installation

```bash
bundle add my-s3-client
# or
# gem install my-s3-client
```

## Quick Start

```ruby
require 'my_s3/client'

client = MyS3::Client.new(
  base_url: 'https://storage.example.com',
  api_key: ENV.fetch('MY_S3_API_KEY')
)

client.ensure_folder_chain('channels/12345/assets')
client.upload_file(
  file_path: '/tmp/avatar.png',
  path: 'channels/12345/assets',
  filename: 'avatar.png'
)

listing = client.list(path: 'channels/12345')
public_url = client.get_public_url(path: 'channels/12345/assets', filename: 'avatar.png')['public_url']
client.download_file(path: 'channels/12345/assets', filename: 'avatar.png', target_path: 'avatar-copy.png')
```

## Covered Endpoints

Each method returns the parsed JSON payload emitted by My.S3 (normally `{ 'success' => true, ... }`). Errors raise `MyS3::Client::Error`.

| Method | Description |
| --- | --- |
| `list(path: '')` | `GET /list.json` to enumerate folders/files. |
| `create_folder(path:, folder_name:)` | `POST /create_folder.json`. |
| `delete_folder(path:)` | `DELETE /delete_folder.json`. |
| `rename_folder(path:, new_name:)` | `POST /rename_folder.json`. |
| `upload_file(file_path:, path: '', filename: nil, ensure_path: true)` | Multipart `POST /upload.json` with automatic folder creation. |
| `delete_file(path:, filename:)` | `DELETE /delete.json`. |
| `delete_older_than(path:, older_than:)` | `POST /delete_older_than.json`. |
| `get_download_url(path:, filename:)` | `POST /get_download_url.json`. |
| `get_public_url(path:, filename:)` | `POST /get_public_url.json`. |
| `download_file(path:, filename:, target_path: nil)` | Streams the anonymous file endpoint (`GET /:path/:filename`). |
| `ensure_folder_chain(path)` | Helper that recursively creates folders via repeated `create_folder` calls. |

## Configuration Tips

- `base_url` should point to the HTTP endpoint exposed by your My.S3 node; a trailing slash is optional.
- `api_key` must match the `api_key` configured on the server.
- Adjust `open_timeout` and `read_timeout` (constructor options) for slower networks or large uploads.
- Combine this gem with background jobs or CLI scripts to automate ingestion, backups, or content rendering pipelines.

## Development

```bash
bundle install
# add specs under test/ or spec/ and run them via your preferred test runner
```

Bug reports and pull requests are welcome.
