# OC-PuppetMaster

Setup script and configuration for a Puppet master server on Ubuntu.

## What it does

`inst.sh` installs and configures:

- Puppet master with Hiera, Facter and r10k.
- PuppetDB backed by PostgreSQL.
- Apache with Phusion Passenger to serve the Puppet master.

The `etc` folder holds the configuration files it uses, including
`puppet.conf`, `hiera.yaml`, `site.pp`, `r10k.yaml`, the PuppetDB
settings and the Apache sites. `var/www` holds a small package
repository and metadata page.

Agents are set up with
[OC-PuppetClient](https://github.com/dmzoneill/OC-PuppetClient).

## Tech

- Bash on Ubuntu
- Puppet 3, PuppetDB, PostgreSQL, Apache and Passenger

## Usage

Run `inst.sh` as root on a fresh Ubuntu server.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).
