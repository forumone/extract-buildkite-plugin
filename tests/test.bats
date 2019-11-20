#!/usr/bin/env bats

set -euo pipefail

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
  export BUILDKITE_PLUGIN_EXTRACT_PULL=false

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
