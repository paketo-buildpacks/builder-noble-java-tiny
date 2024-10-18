#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDERDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly LOCAL_REGISTRY_NAME="builder_test_registry"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROGDIR}/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  local name token skip_cleanup
  token=""
  skip_cleanup=false

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      --name|-n)
        name="${2}"
        shift 2
        ;;

      --token|-t)
        token="${2}"
        shift 2
        ;;

      --skip-cleanup)
        skip_cleanup=true
        shift 1
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  if [[ ! -d "${BUILDERDIR}/smoke" ]]; then
      util::print::warn "** WARNING  No Smoke tests **"
  fi

  if [[ -z "${name:-}" ]]; then
    name="testbuilder"
  fi

  # Build the builder
  "${PROGDIR}/build.sh" --token "${token}" --name "${name}"

  container_id=$(docker ps -aqf "name=${LOCAL_REGISTRY_NAME}")

  if [[ ! -f "${BUILDERDIR}/.bin/pack" ]]; then
    tools::install "${token}"
  fi
  util::tools::path::export "${BUILDERDIR}/.bin"

  name="localhost:5000/${name}"
  image::pull::lifecycle "${name}"
  tests::run "${name}" "${container_id}" "${skip_cleanup}"
}

function usage() {
  cat <<-USAGE
smoke.sh [OPTIONS]

Runs the smoke test suite.

OPTIONS
  --help          -h         prints the command usage
  --name <name>   -n <name>  sets the name of the builder that is built for testing
  --token <token>            token used to download assets from GitHub (e.g. jam, pack, etc) (optional)
  --skip-cleanup             boolean flag to skip clean up of testing images/registry (default: false) (optional)
USAGE
}

function tools::install() {
  local token
  token="${1}"

  util::tools::pack::install \
    --directory "${BUILDERDIR}/.bin" \
    --token "${token}"
}

function local_registry::cleanup() {
  local test_image container_id
  test_image="${1}"
  container_id="${2}"

  echo "Cleaning up local registry ${container_id}..."
  docker kill ${container_id}

  echo "Cleaning up test builder ${test_image}..."
  docker rmi ${test_image}
}

function image::pull::lifecycle() {
  local name lifecycle_image
  name="${1}"

  lifecycle_image="index.docker.io/buildpacksio/lifecycle:$(
   "${BUILDERDIR}"/.bin/pack builder inspect "${name}" --output json \
      | jq -r '.remote_info.lifecycle.version'
  )"

  util::print::title "Pulling lifecycle image..."
  docker pull "${lifecycle_image}"
}

function tests::run() {
  local name container_id
  name="${1}"
  container_id="${2}"
  skip_cleanup="${3}"

  util::print::title "Run Builder Smoke Tests"

  export CGO_ENABLED=0
  testout=$(mktemp)
  pushd "${BUILDERDIR}" > /dev/null
    if GOMAXPROCS="${GOMAXPROCS:-4}" go test -count=1 -timeout 0 ./smoke/... -v -run Smoke --name "${name}" | tee "${testout}"; then
      util::tools::tests::checkfocus "${testout}"
      if ! ${skip_cleanup}; then
        local_registry::cleanup "${name}" "${container_id}"
      fi
      util::print::success "** GO Test Succeeded **"
    else
      if ! ${skip_cleanup}; then
        local_registry::cleanup "${name}" "${container_id}"
      fi
      util::print::error "** GO Test Failed **"
    fi

  popd > /dev/null
}

main "${@:-}"
