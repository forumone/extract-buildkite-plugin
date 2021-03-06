#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

setup() {
  load "../lib/lib"
}

# -- Output functions

@test "Warnings" {
  run warn "Something is suspicious"

  assert_success
  assert_output "WARNING: Something is suspicious"
}

@test "Errors" {
  run error "An error occurred"

  assert_success
  assert_output "ERROR: An error occurred"
}

@test "Verbose disabled" {
  run verbose "Hello, world"

  assert_success
  assert_output ""
}

@test "Verbose enabled" {
  export BUILDKITE_PLUGIN_EXTRACT_VERBOSE=yes
  run verbose "Hello, world"

  assert_success
  assert_output "Hello, world"
}

@test "Header" {
  run header "Header"

  assert_success
  assert_output "~~~ :docker: Header"
}

@test "Fail" {
  run fail-build

  assert_failure
  assert_output "^^^ +++"
}

# -- Utility functions

@test "normalize-path: trailing slashes" {
  run normalize-path "/foo/bar/"

  assert_success
  assert_output "/foo/bar"
}

@test "normalize-path: multiple slashes" {
  run normalize-path "//foo//bar"

  assert_success
  assert_output "/foo/bar"
}

@test "normalize-path: trailing + multiple slashes" {
  run normalize-path "//foo//bar//"

  assert_success
  assert_output "/foo/bar"
}

@test "env-format" {
  run env-format abc-def

  assert_success
  assert_output "ABC_DEF"
}

@test "env-format: stress test" {
  # skip "broken"

  run env-format "asDF31#!*qWE*??"

  assert_success
  assert_output "ASDF31_QWE_"
}

# -- Truthiness tests

@test "is-truthy: 1" {
  run is-truthy 1

  assert_success
  assert_output ""
}

@test "is-truthy: 0" {
  run is-truthy 0

  assert_failure
  assert_output ""
}

@test "is-truthy: on" {
  run is-truthy on

  assert_success
  assert_output ""
}

@test "is-truthy: off" {
  run is-truthy off

  assert_failure
  assert_output ""
}

@test "is-truthy: yes" {
  run is-truthy yes

  assert_success
  assert_output ""
}

@test "is-truthy: no" {
  run is-truthy no

  assert_failure
  assert_output ""
}

@test "is-truthy: true" {
  run is-truthy true

  assert_success
  assert_output ""
}

@test "is-truthy: false" {
  run is-truthy false

  assert_failure
  assert_output ""
}
