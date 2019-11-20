# Docker Extract Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to extract a Docker image to the filesystem before running a build step.

## Example

This will extract the path `/var/www/html` from the image `example/website:latest`:

```yaml
steps:
  - command: tree output
    plugins:
      - forumone/extract:
          image: example/website:latest
          from: /var/www/html
          to: output
```

This shows off all of the options - it extracts the filesystem from a local image (bypassing the normal `docker pull` process) and enables verbose logging:

```yaml
steps:
  - command: tree output
    plugins:
      - forumone/extract:
          image: example/website:latest
          pull: false

          from: /var/www/html
          to: output

          verbose: true
```

## Options

### `image`

A string naming the Docker image to extract from.

### `pull` (optional)

A boolean indicating if the named `image` should be pulled before extraction. Defaults to `true`; set to `false` when testing locally or if the image is built as part of the same pipeline step.

### `from`

A string naming the path to be extracted from the image. This corresponds to the path where you've put your data - `/var/www/html` for most PHP-based images, for example.

### `to` (optional)

A string naming the path on disk to extract to. When left off, defaults to `.` (i.e., the root of the checkout).
