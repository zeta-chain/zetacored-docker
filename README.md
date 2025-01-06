zetacored-docker is a simple way to run snapshot based `zetacored` in docker. It will automatically download the correct `zetacored` version based on the latest snapshot height. It will also automatically upgrade to the latest version of `zetacored` at upgrade height to ensure minimal downtime.

The only environment variable you must set is `MONIKER`. See `run.sh` for the other variables you may set.

A persistent volume should be mounted on `/root`.