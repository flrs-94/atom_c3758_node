## Purpose

These instructions help an AI coding agent work productively in this repository. Focus: NixOS flake-based system configuration for the atom-c3758 host and the Intel QAT tooling overlays.

## High-level architecture

- This repo is a Nix flake (see `flake.nix`) that builds a single NixOS system: `nixosConfigurations.atom-c3758`.
- Overlays: `overlays/qatlib.nix` and `overlays/qat-sdk.nix` provide project-local derivations (`qatlib`, `qat-sdk`) which wrap or fetch Intel's QAT sources.
- Host config: `hosts/atom-c3758.nix` contains the system configuration (kernel params, kernel modules, systemd services) and imports `modules/gitops.nix`.
- `modules/gitops.nix` contains simple systemd units that implement a GitOps pull and a reference rebuild flow.

Why this structure: flakes + overlays keep third-party sources and package derivations together with the host configuration. Modules split concerns (hardware/kernel config vs GitOps/runtime behavior).

## Developer workflows & concrete commands

- Build the NixOS system (from repo root):

```bash
cd /path/to/nixos-config  # repo root
nix build .#nixosConfigurations.atom-c3758.config.system.build.toplevel --out-link ./result-system
```

- Activate the built configuration (the repo includes a helper script `rebuild.sh`):

```bash
# produce and symlink result-system
./rebuild.sh
# or manually
/path/to/repo/result-system/bin/switch-to-configuration switch
```

- Notes: The `rebuild.sh` script expects the repo to be available at `/root/nixos-config` (see script). `modules/gitops.nix` also assumes `/root/nixos-config` in its `nixos-pull` unit. Adjust paths when running locally.

## Repository-specific patterns and gotchas

- Flakes are mandatory here: `flake.nix` uses `nixpkgs` unstable and the configs rely on flakes/`nix-command` experimental features. Ensure `nix` is invoked with flakes enabled.
- Hardware and device IDs are hardcoded (PCI paths like `0000:01:00.0` and `vfio-pci.ids=8086:19e3`). These are host-specific; be cautious when editing or running on different hardware.
- Overlays use `fetchFromGitHub`/`builtins.fetchGit` with pinned revisions/sha256 — if you update the upstream, update the `rev`/`sha256` in `overlays/qatlib.nix` accordingly.
- Many configuration comments are in German — search for # comments in `hosts/atom-c3758.nix` if unsure about intent.

## Integration points & external dependencies

- External upstream: https://github.com/intel/qatlib referenced from `overlays/qatlib.nix`/`qat-sdk.nix`.
- Nixpkgs: the flake pins `nixpkgs` to `nixos-unstable` via `flake.nix` inputs.
- Activation flow: build -> `result-system/bin/switch-to-configuration` (bypasses `nixos-rebuild` in this repo; that's intentional to make builds reproducible and explicit).

## Where to look for common edits

- To change runtime packages or kernel modules: edit `hosts/atom-c3758.nix` (sections: `boot.kernelModules`, `environment.systemPackages`).
- To change how QAT userspace/SDK is built or pinned: edit `overlays/qatlib.nix` or `overlays/qat-sdk.nix`.
- To change automatic GitOps pull/rebuild behavior: edit `modules/gitops.nix`.

## Small contract for code changes from an AI agent

- Inputs: patch to flake files (`.nix` overlays, host/module files) or rebuild script.
- Output: updated `flake.nix`/overlay/host config and a green local build (`nix build` successful).
- Error modes to detect: mismatch sha256 on fetch, flakes disabled locally, missing hardware device paths, attempts to run `switch-to-configuration` without root.

## Quick examples (search targets)

- `flake.nix` — system and overlays wiring
- `overlays/qatlib.nix` — fetchFromGitHub + sha256 pin
- `hosts/atom-c3758.nix` — kernel params, VF/SRIOV units, hardcoded PCI addresses
- `modules/gitops.nix` — systemd units used for GitOps

## Last notes

- There is no test harness in the repo; validate changes by running the `nix build` command above and ensuring the derivation builds. If modifying overlays that change fetch hashes, run `nix-prefetch` or update the `sha256` accordingly.
- If anything in this guidance is unclear or you need examples for a specific change (e.g., adding a package, changing a systemd unit, or updating a pinned revision), tell me which file and I will update the instructions or make a follow-up patch.
