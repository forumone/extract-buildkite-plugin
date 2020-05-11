#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

setup() {
  tempdir="$(mktemp -d)"
}

teardown() {
  rm -rf "$tempdir"
}

# For Docker debugging
# export DOCKER_STUB_DEBUG=/dev/tty

@test "Pulls and extracts" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE=example-image:latest
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_PLUGIN_EXTRACT_TO=nested/output

  stub docker \
    "pull example-image:latest : echo STUB: docker pull" \
    "run --detach example-image:latest : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p nested/output : true"

  stub tar \
    "--file - --extract * : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "STUB: docker pull"
  assert_line "Extracted 0 file(s) from /var/www/html to nested/output"

  unstub docker
  unstub mkdir
  unstub tar
}

@test "Extracts without pulling" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE=example-image:latest
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_PLUGIN_EXTRACT_TO=nested/output
  export BUILDKITE_PLUGIN_EXTRACT_PULL=no

  stub docker \
    "run --detach example-image:latest : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p nested/output : true"

  stub tar \
    "--file - --extract * : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "Extracted 0 file(s) from /var/www/html to nested/output"

  unstub docker
  unstub mkdir
  unstub tar
}

@test "Outputs correct filesystem structure" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE=example-image:latest
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_PLUGIN_EXTRACT_TO="$tempdir/output"

  expected='expected output'

  # Create tar archive for testing
  (
    cd "$tempdir"
    mkdir -p input
    echo "$expected" > input/file.txt
    tar cf archive.tar input
    rm -rf input
  )

  stub docker \
    "pull example-image:latest : echo STUB: docker pull" \
    "run --detach example-image:latest : echo detached" \
    "cp detached:/var/www/html - : cat $tempdir/archive.tar" \
    "container rm detached : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "STUB: docker pull"
  assert_line "Extracted 1 file(s) from /var/www/html to $tempdir/output"

  # Assertion: no cruft
  [ "$(ls -A "$tempdir/output")" == "file.txt" ]

  # Assertion: file.txt exists explicitly (stricter filesystem test than the above)
  [ -e "$tempdir/output/file.txt" ]

  [ "$(cat "$tempdir/output/file.txt")" == "$expected" ]

  unstub docker
}

@test "Determines image from image: key" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE=example-image:latest
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html

  stub docker \
    "pull example-image:latest : true" \
    "run --detach example-image:latest : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p . : true"

  stub tar \
    "* : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "~~~ :docker: Extracting example-image:latest to ."

  unstub docker
  unstub mkdir
  unstub tar
}

@test "Determines image from image-repository: key" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_REPOSITORY=docker.io/user/image
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_SERVICE=drupal
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PIPELINE_SLUG=project

  stub docker \
    "pull docker.io/user/image:project-drupal-build-123 : true" \
    "run --detach docker.io/user/image:project-drupal-build-123 : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p . : true"

  stub tar \
    "* : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "~~~ :docker: Extracting docker.io/user/image:project-drupal-build-123 to ."

  unstub docker
  unstub mkdir
  unstub tar
}

@test "Determines image from Compose plugin configuration" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=docker.io/user/image
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_SERVICE=drupal
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PIPELINE_SLUG=project

  stub docker \
    "pull docker.io/user/image:project-drupal-build-123 : true" \
    "run --detach docker.io/user/image:project-drupal-build-123 : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p . : true"

  stub tar \
    "* : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "~~~ :docker: Extracting docker.io/user/image:project-drupal-build-123 to ."

  unstub docker
  unstub mkdir
  unstub tar
}

@test "Constructs default tag from build metadata" {
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PIPELINE_SLUG=project

  stub docker \
    "pull project-build-123 : true" \
    "run --detach project-build-123 : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p . : true"

  stub tar \
    "* : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "~~~ :docker: Extracting project-build-123 to ."

  unstub docker
  unstub mkdir
  unstub tar
}

@test "Constructs default tag from service and build metadata" {
  export BUILDKITE_PLUGIN_EXTRACT_FROM=/var/www/html
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_SERVICE=drupal
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PIPELINE_SLUG=project

  stub docker \
    "pull project-drupal-build-123 : true" \
    "run --detach project-drupal-build-123 : echo detached" \
    "cp detached:/var/www/html - : true" \
    "container rm detached : true"

  stub mkdir \
    "-p . : true"

  stub tar \
    "* : true"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_line "~~~ :docker: Extracting project-drupal-build-123 to ."

  unstub docker
  unstub mkdir
  unstub tar
}
