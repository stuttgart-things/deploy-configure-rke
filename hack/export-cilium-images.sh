#!/usr/bin/env bash
#
# export-cilium-images.sh — build the air-gapped Cilium images archive from a
# node that already runs Cilium (no internet needed).
#
# Reads the cilium agent/operator/envoy image refs from containerd's local image
# store, then exports them (with digests) into a single tar via `k3s ctr images export`.
# The resulting tar is consumed by the role's
#   k3s ctr -n k8s.io images import --digests <tar>
# (tasks/install-cilium.yaml). Publish it and point cilium_airgapped_image_url
# at it.
#
# Usage:
#   sudo ./export-cilium-images.sh [OUTPUT_TAR]
#
# Env overrides:
#   CTR          ctr command            (default: k3s ctr)
#   NAMESPACE    containerd namespace   (default: k8s.io)
set -euo pipefail

OUT="${1:-cilium-images.tar}"
CTR="${CTR:-k3s ctr}"
NAMESPACE="${NAMESPACE:-k8s.io}"

echo ">> discovering Cilium images from containerd (${NAMESPACE})..."
# Read reference names straight from the local image store. Pod .image fields
# can be the combined "tag@sha256:digest" form, which is NOT a stored reference
# name, so `ctr images export` rejects it ("not found"). The refs listed by
# `ctr images ls` are exactly what export accepts. Drop bare digest entries.
# shellcheck disable=SC2086
mapfile -t IMAGES < <(
  $CTR -n "${NAMESPACE}" images ls -q \
    | grep -i cilium | grep -v '^sha256:' | sort -u
)

if [ "${#IMAGES[@]}" -eq 0 ]; then
  echo "ERROR: no Cilium images found in the cluster." >&2
  exit 1
fi

printf '   - %s\n' "${IMAGES[@]}"

echo ">> exporting ${#IMAGES[@]} image(s) into ${OUT} (namespace ${NAMESPACE})..."
# shellcheck disable=SC2086
$CTR -n "${NAMESPACE}" images export "${OUT}" "${IMAGES[@]}"

echo ">> generating checksum..."
sha256sum "${OUT}" | tee "${OUT}.sha256"

echo
echo "Done: ${OUT} ($(du -h "${OUT}" | cut -f1))"
echo "Set in defaults/inventory:"
echo "  cilium_airgapped_images: true"
echo "  cilium_airgapped_image_url: \"https://<your-store>/$(basename "${OUT}")\""
echo "  cilium_image_pull_policy: Never"
echo "  cilium_airgapped_checksum: \"sha256:$(cut -d' ' -f1 "${OUT}.sha256")\""
