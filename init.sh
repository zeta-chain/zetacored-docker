#!/bin/bash

set -eo pipefail

if [[ -n $DEBUG ]]; then
  set -x
fi

# script variables
ZETACHAIN_NETWORK=${ZETACHAIN_NETWORK:-"mainnet"}
ZETACHAIN_SNAPSHOT_TYPE=${ZETACHAIN_SNAPSHOT_TYPE:-"fullnode"}
ZETACORED_BINARY_URL=${ZETACORED_BINARY_URL:-}
MY_IP=${MY_IP:-$(curl -s https://checkip.amazonaws.com)}

# script constants
CURL="curl -s -L --fail --retry 5 --retry-delay 2 --retry-max-time 10"

if [[ -z $MONIKER ]]; then
  echo '$MONIKER is required'
  exit 1
fi

if [[ "$ZETACHAIN_NETWORK" == "mainnet" ]]; then
  echo "Running mainnet"
  ZETACHAIN_INIT_API_URL=${ZETACHAIN_INIT_API_URL:-"https://zetachain-mainnet.g.allthatnode.com/archive/rest"}
  ZETACHAIN_SNAPSHOT_METADATA_URL=${ZETACHAIN_SNAPSHOT_METADATA_URL:-"https://snapshots.rpc.zetachain.com/mainnet/${ZETACHAIN_SNAPSHOT_TYPE}/latest.json"}
  ZETACHAIN_NETWORK_CONFIG_URL_BASE=${ZETACHAIN_NETWORK_CONFIG_URL_BASE:-"https://raw.githubusercontent.com/zeta-chain/network-config/main/mainnet"}
elif [[ "$ZETACHAIN_NETWORK" == "testnet" || "$ZETACHAIN_NETWORK" == "athens3" ]]; then
  echo "Running testnet"
  ZETACHAIN_INIT_API_URL=${ZETACHAIN_INIT_API_URL:-"https://zetachain-athens.g.allthatnode.com/archive/rest"}
  ZETACHAIN_SNAPSHOT_METADATA_URL=${ZETACHAIN_SNAPSHOT_METADATA_URL:-"https://snapshots.rpc.zetachain.com/testnet/${ZETACHAIN_SNAPSHOT_TYPE}/latest.json"}
  ZETACHAIN_NETWORK_CONFIG_URL_BASE=${ZETACHAIN_NETWORK_CONFIG_URL_BASE:-"https://raw.githubusercontent.com/zeta-chain/network-config/main/athens3"}
else 
  echo "Invalid network"
  exit 1
fi

# convert uname arch to goarch style
UNAME_ARCH=$(uname -m)
case "$UNAME_ARCH" in
    x86_64)    GOARCH=amd64;;
    i686)      GOARCH=386;;
    armv7l)    GOARCH=arm;;
    aarch64)   GOARCH=arm64;;
    *)         GOARCH=unknown;;
esac

download_configs() {
  echo "Downloading configs if they are not present"
  mkdir -p .zetacored/config/
  mkdir -p .zetacored/data/
  if [[ ! -f .zetacored/config/app.toml ]]; then
    $CURL -o .zetacored/config/app.toml "${ZETACHAIN_NETWORK_CONFIG_URL_BASE}/app.toml"
  fi
  if [[ ! -f .zetacored/config/config.toml ]]; then
    $CURL -o .zetacored/config/config.toml "${ZETACHAIN_NETWORK_CONFIG_URL_BASE}/config.toml"
    sed -i -e "s/^moniker = .*/moniker = \"${MONIKER}\"/" .zetacored/config/config.toml
  fi
  if [[ ! -f .zetacored/config/client.toml ]]; then
    $CURL -o .zetacored/config/client.toml "${ZETACHAIN_NETWORK_CONFIG_URL_BASE}/client.toml"
  fi
  if [[ ! -f .zetacored/config/genesis.json ]]; then
    $CURL -o .zetacored/config/genesis.json "${ZETACHAIN_NETWORK_CONFIG_URL_BASE}/genesis.json"
  fi
}

install_genesis_zetacored() {
  echo "Installing genesis zetacored"
  if [[ -z $ZETACORED_BINARY_URL ]]; then
    max_height=$($CURL "${ZETACHAIN_SNAPSHOT_METADATA_URL}" | jq -r '.snapshots[0].height')
    echo "Getting latest passed upgrade plan before ${max_height}"
    $CURL "${ZETACHAIN_INIT_API_URL}/cosmos/gov/v1/proposals?pagination.reverse=true" | jq --arg max_height "$max_height" '
      .proposals[] |
      select(.status == "PROPOSAL_STATUS_PASSED") |
      .messages[] |
      select(."@type" == "/cosmos.upgrade.v1beta1.MsgSoftwareUpgrade" and (.plan.height | 
      tonumber < $max_height))' | jq -s '.[0]' | tee /tmp/init-upgrade-plan.json

    ZETACORED_BINARY_URL=$(jq -r '.plan.info' /tmp/init-upgrade-plan.json | jq -r ".binaries[\"linux/$GOARCH\"]")
  fi
  # go-getter will verify the checksum of the downloaded binary
  go-getter --mode file "$ZETACORED_BINARY_URL" .zetacored/cosmovisor/genesis/bin/zetacored
  chmod +x .zetacored/cosmovisor/genesis/bin/zetacored

  # run the zetacored version to ensure it's the correct architecture, glibc version, and is in PATH
  zetacored version
}

restore_snapshot() {
  snapshot_link=$($CURL "${ZETACHAIN_SNAPSHOT_METADATA_URL}" | jq -r '.snapshots[0].link')
  echo "Restoring snapshot from ${snapshot_link}"
  $CURL "$snapshot_link" | tar x -C $HOME/.zetacored
}

cd $HOME

if [[ -f /root/init_started && ! -f /root/init_completed ]]; then
  echo "Initialization interrupted, resetting node data"
  rm -rf .zetacored/data/*
fi

touch /root/init_started
if [[ ! -f /root/init_complete ]]; then
  echo "Starting initialization"
  download_configs
  install_genesis_zetacored
  restore_snapshot
  touch /root/init_complete
else 
  echo "Initialization already completed"
fi

# always set IP address as it may change after restart
sed -i -e "s/^external_address = .*/external_address = \"${MY_IP}:26656\"/" .zetacored/config/config.toml