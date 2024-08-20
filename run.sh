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

# shellcheck disable=SC2068
exec cosmovisor run start --moniker "$MONIKER" $@