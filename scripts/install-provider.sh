#!/usr/bin/env bash
set -euo pipefail

PROVIDER_VERSION="${ACA_TF_PROVIDER_VERSION:-0.5.0-preview}"
PROVIDER_REPOSITORY="${ACA_TF_PROVIDER_REPOSITORY:-Azure/terraform-provider-aca}"
TERRAFORM_PLATFORM="${ACA_TF_PLATFORM:-}"
MIRROR_ROOT="${ACA_TF_MIRROR_ROOT:-$PWD/.terraform-provider-mirror}"
CONFIG_PATH="${ACA_TF_CONFIG_PATH:-$PWD/terraform.rc}"

if [[ -z "$TERRAFORM_PLATFORM" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "Terraform is required to detect the provider platform." >&2
    exit 1
  fi
  TERRAFORM_PLATFORM="$(terraform version | awk '$1 == "on" { print $2; exit }')"
fi

case "$TERRAFORM_PLATFORM" in
  linux_amd64|linux_arm64|darwin_amd64|darwin_arm64) ;;
  *)
    echo "Unsupported Terraform platform for the Bash installer: $TERRAFORM_PLATFORM" >&2
    exit 1
    ;;
esac

ARCHIVE="terraform-provider-aca_${PROVIDER_VERSION}_${TERRAFORM_PLATFORM}.zip"
CHECKSUMS="terraform-provider-aca_${PROVIDER_VERSION}_SHA256SUMS"
RELEASE_URL="${ACA_TF_PROVIDER_RELEASE_URL:-https://github.com/${PROVIDER_REPOSITORY}/releases/download/provider-v${PROVIDER_VERSION}}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

curl -fsSL "$RELEASE_URL/$ARCHIVE" -o "$TEMP_DIR/$ARCHIVE"
curl -fsSL "$RELEASE_URL/$CHECKSUMS" -o "$TEMP_DIR/$CHECKSUMS"

EXPECTED="$(awk -v file="$ARCHIVE" '$2 == file || $2 == "./" file { print $1; exit }' "$TEMP_DIR/$CHECKSUMS")"
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$TEMP_DIR/$ARCHIVE" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "$TEMP_DIR/$ARCHIVE" | awk '{ print $1 }')"
else
  echo "Install sha256sum or shasum to verify the provider archive." >&2
  exit 1
fi

if [[ -z "$EXPECTED" || "$ACTUAL" != "$EXPECTED" ]]; then
  echo "Provider archive checksum verification failed." >&2
  exit 1
fi

mkdir -p "$MIRROR_ROOT"
MIRROR_ROOT="$(cd "$MIRROR_ROOT" && pwd -P)"
TARGET="$MIRROR_ROOT/registry.terraform.io/azure/aca/${PROVIDER_VERSION}/${TERRAFORM_PLATFORM}"
mkdir -p "$TARGET"
unzip -qo "$TEMP_DIR/$ARCHIVE" -d "$TARGET"

PROVIDER_BINARY="$TARGET/terraform-provider-aca_v${PROVIDER_VERSION}"
if [[ ! -f "$PROVIDER_BINARY" ]]; then
  echo "Provider archive did not contain $PROVIDER_BINARY." >&2
  exit 1
fi
chmod +x "$PROVIDER_BINARY"

mkdir -p "$(dirname "$CONFIG_PATH")"
cat > "$CONFIG_PATH" <<EOF
provider_installation {
  filesystem_mirror {
    path    = "$MIRROR_ROOT"
    include = ["registry.terraform.io/azure/aca"]
  }
  direct {
    exclude = ["registry.terraform.io/azure/aca"]
  }
}
EOF

echo "Installed registry.terraform.io/azure/aca v${PROVIDER_VERSION} for ${TERRAFORM_PLATFORM}."
echo "Set TF_CLI_CONFIG_FILE=$CONFIG_PATH before running terraform init."
