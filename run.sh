#!/bin/bash

set -eo pipefail

if [[ -n $DEBUG ]]; then
  set -x
fi

"$(dirname "$0")/init.sh"

# cosmovisor variables
export DAEMON_ALLOW_DOWNLOAD_BINARIES=${DAEMON_ALLOW_DOWNLOAD_BINARIES:-"true"}
export DAEMON_RESTART_AFTER_UPGRADE=${DAEMON_RESTART_AFTER_UPGRADE:-"true"}
export DAEMON_NAME="zetacored"
export DAEMON_HOME="$HOME/.zetacored"
export UNSAFE_SKIP_BACKUP=true

# apply any version overrides
# these should run on every start the version can change at any time
/apply_version_overrides.sh

# shellcheck disable=SC2068
exec cosmovisor run start --moniker "$MONIKER" $@