#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

setup() {
  load "../lib/lib"
}

# -- Basic config

@test "config-key: image-tag" {
  run config-key image-tag

  assert_success
  assert_output "BUILDKITE_PLUGIN_EXTRACT_IMAGE_TAG"
}

@test "config-key: docker-compose image-repository" {
  run config-key docker-compose image-repository

  assert_success
  assert_output "BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY"
}

@test "get-config: image-tag" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_TAG=foo

  run get-config image-tag

  assert_success
  assert_output "foo"
}

@test "get-config: docker-compose image-repository" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=foo

  run get-config docker-compose image-repository

  assert_success
  assert_output "foo"
}

@test "get-config-with-default: image-tag foo (when unset)" {
  run get-config-with-default image-tag foo

  assert_success
  assert_output "foo"
}

@test "get-config-with-default: image-tag foo (when set)" {
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_TAG=bar

  run get-config-with-default image-tag foo

  assert_success
  assert_output "bar"
}

@test "get-config-with-default: docker-compose image-repository foo (when unset)" {
  run get-config-with-default docker-compose image-repository foo

  assert_success
  assert_output "foo"
}

@test "get-config-with-default: docker-compose image-repository foo (when set)" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=bar

  run get-config-with-default docker-compose image-repository foo

  assert_success
  assert_output "bar"
}

# -- Image tags

@test "generate-tag: service unset" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123

  run generate-tag

  assert_success
  assert_output "pipeline-build-123"
}

@test "generate-tag: service set" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_SERVICE=drupal

  run generate-tag

  assert_success
  assert_output "pipeline-drupal-build-123"
}

@test "image-tag: tag unset" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123

  run image-tag

  assert_success
  assert_output "pipeline-build-123"
}

@test "image-tag: tag set" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_TAG=foobar

  run image-tag

  assert_success
  assert_output "foobar"
}

# -- Image names

@test "generate-name: nothing set" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123

  run generate-name

  assert_success
  assert_output "pipeline-build-123"
}

@test "generate-name: repo set (extract config)" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_REPOSITORY=extract

  run generate-name

  assert_success
  assert_output "extract:pipeline-build-123"
}

@test "generate-name: repo set (compose config)" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=docker-compose

  run generate-name

  assert_success
  assert_output "docker-compose:pipeline-build-123"
}

@test "generate-name: repo cascade" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE_REPOSITORY=extract
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=docker-compose

  run generate-name

  assert_success
  assert_output "extract:pipeline-build-123"
}

@test "image-name: nothing set" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123

  run image-name

  assert_success
  assert_output "pipeline-build-123"
}

@test "image-name: image set" {
  export BUILDKITE_PIPELINE_SLUG=pipeline
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_PLUGIN_EXTRACT_IMAGE=image

  run image-name

  assert_success
  assert_output "image"
}

# Still to come: testing invalid image combinations to ensure that weird configuration combos
# are caught and addressed.
