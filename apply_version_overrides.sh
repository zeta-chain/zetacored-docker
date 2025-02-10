#!/bin/bash

set -eo pipefail

if [[ -n $DEBUG ]]; then
  set -x
fi

upgrades_path="${HOME}/.zetacored/cosmovisor/upgrades/"

for version_dir in "$upgrades_path"/*/; do
  if [ ! -d "$version_dir" ]; then
    continue
  fi
  # Extract version name from path
  version=$(basename "$version_dir")
  # Check for override variable
  override_var="VERSION_OVERRIDE_${version}"
  if [ -n "${!override_var}" ]; then
    echo "Found override for version $version: ${!override_var}"
    # Download binary using go-getter
    if go-getter --mode file "${!override_var}" /tmp/zetacored; then
      # If download successful, move to correct location
      chmod +x /tmp/zetacored
      mv /tmp/zetacored "${version_dir}/bin/zetacored"
      echo "Successfully updated binary for version $version"
    else
      echo "Failed to download binary for version $version, using existing version"
    fi
  fi
done