---
title: MTCBPC Home Server
author: [ Matthew T. C. Boyea ]
lang: en
keywords: [ ]
default_: readme
---
## Code to run a few Linux servers out of my Windows PC

Tested and compiled using [WSL2 Ubuntu with Nix installed](https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki).

Outputs a NixOS Linux ISO for use in a VM to keep servers sandboxed.

Contents include:

- Passward manager with Vault Warden
- Photo manager with Immich
- Document manager with Seafile

### Installation

First, copy this repository.

- [Clone this repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository) from GitHub to your computer

Then, install Nix (the package manager).

- [Install Nix](https://nixos.org/download)
- [Enable Flakes](https://nixos.wiki/wiki/Flakes)

Optionally install direnv (to automatically run `nix develop` when your terminal enters into the project directory).

- [Install direnv](https://direnv.net/docs/installation.html)
- Open a terminal in this project's root directory
- Run command `direnv allow`

### Usage

Be sure to [read the license](./license.md).

#### Scripts

If you have not enabled direnv, run `nix develop` to start the development shell.
Scripts can be run from within any of the project directories.

| Command | Description |
|:--- |:--- |
| `nix develop` | Start a subshell with the project dependencies installed; Not needed with direnv enabled |
| `run [script]` | Run a script; This is an alias for 'nix run .#[script] [args...]' but with a cache of the derivation output |

| Script | Description |
|:--- |:--- |
| `help` | Print usage information for this software |

Scripts are declared in [flake.nix](./flake.nix) and defined in [scripts/](./scripts).
