export image_name := env("IMAGE_NAME", "asdx")
export default_tag := env("DEFAULT_TAG", "latest")
export recipe := env("BLUEBUILD_RECIPE", "recipes/asdx.yml")
export arm64_recipe := env("BLUEBUILD_ARM64_RECIPE", "recipes/asdx-arm64.yml")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

[private]
default:
    @just --list

# Check Just syntax and, when available, BlueBuild recipe expansion.
[group('Validate')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt --check -f Justfile
    if command -v bluebuild >/dev/null 2>&1; then
      bluebuild generate -d "{{ recipe }}" >/dev/null
      bluebuild generate -d "{{ arm64_recipe }}" >/dev/null
    else
      echo "bluebuild not found; skipping recipe generation check" >&2
    fi

# Format the Justfile.
[group('Validate')]
fix:
    just --unstable --fmt -f Justfile

# Generate a Containerfile preview from the BlueBuild recipe.
[group('Build')]
generate-containerfile:
    bluebuild generate "{{ recipe }}" -o Containerfile

# Build the ASDX image locally from the BlueBuild recipe.
[group('Build')]
build:
    bluebuild build "{{ recipe }}"

# Build the ARM64 UTM test image locally from the BlueBuild recipe.
[group('Build')]
build-arm64:
    bluebuild build --platform linux/arm64 "{{ arm64_recipe }}"

# Build and push the ASDX image using BlueBuild's local CLI.
[group('Build')]
build-push:
    bluebuild build --push "{{ recipe }}"

# Build and push the ARM64 UTM test image using BlueBuild's local CLI.
[group('Build')]
build-push-arm64:
    bluebuild build --push --platform linux/arm64 "{{ arm64_recipe }}"

# Build locally and rebase the current machine using BlueBuild's switch flow.
[group('Install')]
switch:
    bluebuild switch "{{ recipe }}"

# Build locally and immediately reboot into the new deployment.
[group('Install')]
switch-reboot:
    bluebuild switch --reboot "{{ recipe }}"

# Build a qcow2 disk image from an already-built local image.
[group('Disk')]
build-qcow2 target_image=("localhost/" + image_name) tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    image_ref="{{ target_image }}:{{ tag }}"
    if ! sudo podman image exists "${image_ref}"; then
      arch_ref="{{ target_image }}:{{ tag }}_linux_amd64"
      if sudo podman image exists "${arch_ref}"; then
        image_ref="${arch_ref}"
      fi
    fi

    buildtmp="$(mktemp -d "${PWD}/_build-bib.XXXXXXXXXX")"
    sudo podman run \
      --rm \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v "${PWD}/disk_config/disk.toml:/config.toml:ro" \
      -v "${buildtmp}:/output" \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "{{ bib_image }}" \
      --type qcow2 \
      --use-librepo=True \
      --rootfs=btrfs \
      "${image_ref}"

    mkdir -p output
    sudo mv -f "${buildtmp}"/* output/
    sudo rmdir "${buildtmp}"
    sudo chown -R "${USER}:${USER}" output/

# Build a qcow2 disk image for UTM from the ARM64 test image.
[group('Disk')]
build-qcow2-arm64 target_image="localhost/asdx-arm64" tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    image_ref="{{ target_image }}:{{ tag }}"
    if ! sudo podman image exists "${image_ref}"; then
      arch_ref="{{ target_image }}:{{ tag }}_linux_arm64"
      if sudo podman image exists "${arch_ref}"; then
        image_ref="${arch_ref}"
      fi
    fi

    buildtmp="$(mktemp -d "${PWD}/_build-bib.XXXXXXXXXX")"
    sudo podman run \
      --rm \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v "${PWD}/disk_config/disk.toml:/config.toml:ro" \
      -v "${buildtmp}:/output" \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "{{ bib_image }}" \
      --type qcow2 \
      --use-librepo=True \
      --rootfs=btrfs \
      "${image_ref}"

    mkdir -p output-arm64
    sudo mv -f "${buildtmp}"/* output-arm64/
    sudo rmdir "${buildtmp}"
    sudo chown -R "${USER}:${USER}" output-arm64/

# Remove local build outputs.
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf _build_* output output-arm64 previous.manifest.json changelog.md output.env
