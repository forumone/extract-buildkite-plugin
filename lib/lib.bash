# ABOUT THIS FILE
#
# This file contains library-style functions that have been extracted from the pre-command
# hook for two reasons:
#
# 1. It simplifies reading the pre-command hook, and
# 2. It makes it easier to test these functions in isolation.

# We use extended glob syntax in a few text replacement functions
shopt -s extglob

# Usage:
#   env-format KEY
#
# KEY: A full or partial configuration key name such as "image-repository"
#
# Formats a key into Buildkite's serialized environment format: bad characters are
# replaced with underscores, and all text is capitalized. This allows users to write
# "foo-bar" and have it be formatted properly.
env-format() {
  local key="${1//+([^a-zA-Z0-9])/_}"
  echo "${key^^}"
}

# Usage:
#   is-truthy VALUE
#
# VALUE: A string value to check
#
# Checks for things that look kinda like a true value (we're pretty lenient)
is-truthy() {
  [[ "$1" =~ ^1|on|yes|true$ ]]
}

# Usage:
#   verbose [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Wrapper for echo that only outputs if the verbose config option is set
verbose() {
  if is-truthy "$(get-config verbose)"; then
    echo "$@"
  fi
}

# Usage:
#   error [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Reports an error to stderr
error() {
  echo ERROR: "$@" >&2
}

# Usage:
#   warn [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Reports a warning to stderr
warn() {
  echo WARNING: "$@" >&2
}

# Usage:
#   header [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Outputs a header
header() {
  echo '~~~ :docker:' "$@"
}

# Usage:
#   fail-build
#
# Function to hard fail, opening any collapsed output
fail-build() {
  echo "^^^ +++"
  exit 1
}

# Usage:
#   normalize-path PATH
#
# PATH: A POSIX path
#
# Normalizes a path: trailing slashes are removed, and multiple slashes are collapsed to a
# single one.
normalize-path() {
  # The ${...} substition strips trailing slashes, and the -s flag to tr means to collapse
  # multiple matches of the source set - in our case, we're lightly abusing it since the
  # "replacement" is the same as the original character.
  tr -s / / <<<"${1%%+(/)}"
}

# Usage:
#   config-key OPTION
#   config-key PLUGIN OPTION
#
# OPTION: A configuration option, in hyphenated format (e.g., "image-service").
# PLUGIN: The name of a Buildkite plugin, which defaults to "extract". This exists to
#         support peeking at the Docker Compose plugin's configuration in cases where we
#         want to share it (mostly for the image-repository configuration option.)
#
# This function transforms kebab-cased option and plugin names into the corresponding
# environment variable name, matching the format BUILDKITE_PLUGIN_<plugin name>_<option name>.
config-key() {
  local key
  local plugin=extract
  if test $# -eq 2; then
    plugin="$1"
    key="$2"
  else
    key="$1"
  fi

  echo "BUILDKITE_PLUGIN_$(env-format "$plugin")_$(env-format "$key")"
}

# Usage:
#   get-config OPTION
#   get-config PLUGIN OPTION
#
# See config-key for definition of PLUGIN and OPTION.
#
# This reads out the named configuration option. If the value is not present in the
# environment, the empty string is returned.
get-config() {
  local key
  key="$(config-key "$@")"

  echo "${!key:-}"
}

# Usage:
#   get-config-with-default OPTION DEFAULT
#   get-config-with-default PLUGIN OPTION DEFAULT
#
# See config-key for definition of PLUGIN and OPTION.
# DEFAULT: The default value to use instead of the empty string.
#
# This reads out the named configuration option. If the option is not present (or is
# empty), then DEFAULT is returned instead.
get-config-with-default() {
  local key
  local plugin=extract
  local default

  if test $# -eq 3; then
    plugin="$1"
    key="$2"
    default="$3"
  else
    key="$1"
    default="$2"
  fi

  local value
  value="$(get-config "$plugin" "$key")"

  echo "${value:-$default}"
}

# Usage:
#   validate-config
#
# This function should be called first: it's crucial to ensure that the configuration is
# fully validated before any actions are taken.
validate-config() {
  # First, determine if the debug option has been set. This way, users can triage the
  # behavior of this function in case it appears broken.
  if is-truthy "$(get-config debug)"; then
    set -x
  fi

  # Track failures in a counter - this way we can report all issues to the user at once.
  local failed=0

  # Get the config values we need
  local image repository service tag
  image="$(get-config image)"
  repository="$(get-config image-repository)"
  service="$(get-config image-service)"
  tag="$(get-config image-tag)"

  # First, validate that the user hasn't somehow specified the image key and its children
  # at the same time - this can happen either by setting vars explicitly in the agent
  # environment or by accidentally writing a key like "image-service:" in the config.
  local has_image=
  local has_object=

  if test -n "$image"; then
    has_image=1
  fi

  if test -n "$repository" || test -n "$service" || test -n "$tag"; then
    has_object=1
  fi

  # NB. Recommended structure: error message, blank line, remediation steps
  if test -n "$has_image" && test -n "$has_object"; then
    error "Both the image name and options were specified at the same time."
    error
    error "If you want to use an image name directly, you should ensure that you have not"
    error "specified a configuration key such as image-service or accidentally defined an"
    error "environment variable such as BUILDKITE_PLUGIN_EXTRACT_IMAGE_SERVICE."
    failed=$((failed + 1))
  fi

  # Next, ensure that the conflicting tag and service keys have not been provided.
  local has_tag=
  local has_service=

  if test -n "$tag"; then
    has_tag=1
  fi

  if test -n "$service"; then
    has_service=1
  fi

  if test -n "$has_tag" && test -n "$has_service"; then
    error "Both the image tag and image service options were specified at the same time."
    error
    error "These options are mutually exclusive. Please remove one."
    failed=$((failed + 1))
  fi

  # Third, detect if an image option was specified at the top level by accident. We use
  # an array of misconfigured keys to let the user know how to remedy this issue.
  local -a options=()
  local key

  for key in tag service repository; do
    if test -n "$(get-config "$key")"; then
      options+=("$key")
    fi
  done

  local count="${#options[@]}"
  if test "$count" -gt 0; then
    # First, notify the user of the issue (respecting plurals)
    if test "$count" -eq 1; then
      error "An image option was encountered as a top-level configuration item."
    else
      error "Some image options were encountered as top-level configuration items."
    fi

    # Blank line to match common image format
    error

    # Now, dump all the configuration keys that we believe are incorrect and indicate
    # where they should live.
    error "To remedy, please move the invalid configuration"
    error "    image:"
    for key in "${options[@]}"; do
      error "      ${key}: $(get-config "$key")"
    done

    failed=$((failed + 1))
  fi

  # Check for the presence of the required from option.
  if test -z "$(get-config from)"; then
    error "The required from option is not present."
    error
    error "This plugin requires the from option to know which path to extract from the Docker"
    error "image."

    failed=$((failed + 1))
  fi

  # If we encountered any failures, then it's time to bail - the configuration isn't
  # trustworthy.
  if test "$failed" -gt 0; then
    fail-build
  fi
}

# USAGE:
#   generate-tag
#
# Generates a tag in one of two forms:
# 1. <pipeline slug>-build-<build number>
# 2. <pipeline slug>-<service>-build-<build number>
#
# The former option is chosen if there is no service configuration provided, and the
# latter is designed to mimic the Buildkite Docker Compose plugin's (see link below).
#
# Note that this function should not be called directly in the plugin hook. See the
# image-name function instead.
#
# cf. https://github.com/buildkite-plugins/docker-compose-buildkite-plugin/blob/398a7ff32422d2911a0c32c71d8e5e2749cdf41d/lib/shared.bash#L191-L203
generate-tag() {
  local service
  service="$(get-config image-service)"

  # $separator will be empty if $service is, and "-" otherwise
  local separator="${service:+-}"

  echo "${BUILDKITE_PIPELINE_SLUG}-${service}${separator}build-${BUILDKITE_BUILD_NUMBER}"
}

# USAGE:
#   image-tag
#
# Returns the tag to use for this image. It respects the image configuration option, but
# knows how to generate an image tag otherwise.
#
# Note that this function should not be called directly in the plugin hook. See the
# image-name function instead.
image-tag() {
  # The image tag option supersedes the auto-generated tag
  local tag
  tag="$(get-config image-tag)"

  echo "${tag:-$(generate-tag)}"
}

# USAGE:
#   generate-name
#
# Generates a name for the image based on configuration. It will use the configuration to
# determine which tag to apply, and then attemps to look up the repository based on either
# this plugin's configuration or the Docker Compose plugin's configuration, whichever
# comes first.
#
# Note that this function should not be called directly in the plugin hook. See the
# image-name function instead.
generate-name() {
  # First, determine the tag
  local tag
  tag="$(image-tag)"

  # Next, determine the image repository.
  local repository=

  # First, we attempt to look it up in this plugin's configuration.
  repository="$(get-config image-repository)"

  # Second, we attempt to look it up in the Docker Compose plugin's configuration. The
  # ":-" notation skips the get-config function call if there already is a non-empty
  # string value, which is what we want - this plugin's configuration takes precedence
  # over the Compose plugin's configuration.
  repository="${repository:-$(get-config docker-compose image-repository)}"

  # $separator will be empty if $repository is, and ":" otherwise
  local separator="${repository:+:}"

  echo "$repository$separator$tag"
}

# USAGE:
#   image-name
#
# This function determines, based on configuration, the name of the image to extract.
image-name() {
  local image
  image="$(get-config image)"

  echo "${image:-$(generate-name)}"
}
