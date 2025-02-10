zetacored-docker is a simple way to run snapshot based `zetacored` in docker. It will automatically download the correct `zetacored` version based on the latest snapshot height. It will also automatically upgrade to the latest version of `zetacored` at upgrade height to ensure minimal downtime.

The only environment variable you must set is `MONIKER`. See `run.sh` for the other variables you may set.

A persistent volume should be mounted on `/root`.

## Version Overrides

You may override a specific version by setting `VERSION_OVERRIDE_${version}=URL` variable. This is mostly useful for deploying minor non-consensus breaking patches. Example:

```
VERSION_OVERRIDE_v27=https://github.com/zeta-chain/node/releases/download/v27.0.4/zetacored-linux-amd64
```

The old version will be ran if the download of this file changes.