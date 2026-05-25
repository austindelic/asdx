# ASDX

```
       d8888  .d8888b.  8888888b. Y88b   d88P
      d88888 d88P  Y88b 888  "Y88b Y88b d88P
     d88P888 Y88b.      888    888  Y88o88P
    d88P 888  "Y888b.   888    888   Y888P
   d88P  888     "Y88b. 888    888   d888b
  d88P   888       "888 888    888  d88888b
 d8888888888 Y88b  d88P 888  .d88P d88P Y88b
d88P     888  "Y8888P"  8888888P" d88P   Y88b
```

ASDX is a COSMIC-first Fedora Atomic / Universal Blue-based productivity OS.

The default image is designed to be a modern workstation base: atomic,
developer-focused, COSMIC by default, and GPU-friendly for AMD, Intel, and
modern Nvidia systems.

## Status

ASDX v0.1 is focused on the bootable image milestone:

- Image: `asdx`
- UTM test image: `asdx-arm64`
- Base: `ghcr.io/ublue-os/base-main:latest`
- Desktop: COSMIC
- Build system: BlueBuild / bootc OCI image
- GPU policy: AMD, Intel, and modern Nvidia in the default image
- Nvidia driver flavor: `nvidia-open`
- Apple Silicon / UTM test image: ARM64 only, no Nvidia akmods
- `ax`: deferred until the package manager artifact is ready
- ISO: deferred until image rebasing is working

## Image Design

ASDX is productivity-first, not Hyprland-first. COSMIC is the default session
and should provide a normal floating desktop workflow by default, with COSMIC
tiling available for users who want it.

The base OS stays lean. System-level packages are limited to COSMIC, Flatpak,
Podman, Distrobox, shell/editor basics, hardware helpers, and core workstation
tools. User-facing GUI apps should come from Flatpak. CLI packages and dev tools
will be routed through `ax` later using Homebrew and mise.

## Build

The source of truth is [recipes/asdx.yml](recipes/asdx.yml).

Local prerequisites:

- `bluebuild`
- `podman` or another supported container builder
- `just`

Useful commands:

```bash
just check
just build
just build-arm64
just generate-containerfile
```

`Containerfile` is not committed as the build source. Generate it locally when
you need to inspect the BlueBuild output:

```bash
bluebuild generate recipes/asdx.yml -o Containerfile
```

## CI

The container image workflow builds `recipes/asdx.yml` with
`blue-build/github-action`.

- Pull requests build the recipe for validation.
- Pushes to the default branch publish `ghcr.io/<owner>/asdx:latest`.
- Published images are signed with the repository `SIGNING_SECRET`.

The disk workflow is qcow2-only for now. Installer ISO generation is intentionally
left for a later milestone.

## UTM Apple Silicon

Use the ARM64 test recipe for UTM on Apple Silicon. It keeps the COSMIC desktop
and workstation package set, but intentionally omits Nvidia akmods.

Inside an ARM64 Fedora builder VM:

```bash
just check
sudo env PATH="$PATH" just build-arm64
just build-qcow2-arm64
```

Import the qcow2 from `output-arm64/` into UTM as a virtualized Linux VM.

## Rebase

From an existing Fedora Atomic or Universal Blue system, rebase to the unsigned
image first:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<owner>/asdx:latest
sudo systemctl reboot
```

Then switch to the signed image:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/<owner>/asdx:latest
sudo systemctl reboot
```

Replace `<owner>` with the GitHub owner or organization that publishes the image.

## Milestones

1. Bootable image: build from `base-main`, publish to GHCR, rebase a test
   machine, and reach a COSMIC session.
2. COSMIC defaults: wallpaper, theme, default apps, greeter polish, fastfetch
   branding, and a floating-first desktop workflow.
3. GPU support: AMD, Intel, and modern Nvidia verification, including
   `nvidia-smi` on supported Nvidia systems.
4. `ax` baked in: install `/usr/bin/ax`, global config, profiles, and `ax doctor`.
5. ISO: generate an installer ISO only after image rebasing works.
