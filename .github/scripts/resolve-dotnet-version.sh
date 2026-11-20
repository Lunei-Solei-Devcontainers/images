#!/bin/bash

set -euo pipefail

dotnet="${1:?usage: resolve-dotnet-version.sh <dotnet>}"
base="${RELEASE_METADATA_BASE:-https://builds.dotnet.microsoft.com/dotnet/release-metadata}"

sdk=""
runtime=""

if [[ "$dotnet" =~ ^[0-9]+\.[0-9]+$ ]]; then
  metadata=$(curl -fsSL --retry 3 "$base/$dotnet/releases.json")
  phase=$(jq -r '."support-phase"' <<<"$metadata")
  case "$phase" in
    preview|go-live)
      echo ".NET $dotnet is in phase '$phase'; no stable patch to compare against." >&2
      ;;
    *)
      sdk=$(jq -r '."latest-sdk"' <<<"$metadata")
      runtime=$(jq -r '."latest-runtime"' <<<"$metadata")
      ;;
  esac
elif [[ "$dotnet" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  sdk="$dotnet"
else
  echo "dotnet '$dotnet' is not pinned channel or version; skipping patch check." >&2
fi

# These values are interpolated into a shell snippet by the workflow, and two of them
# come from the network. Refuse anything that does not look like a version.
for value in "$sdk" "$runtime"; do
  if [ -n "$value" ] && ! [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "Unexpected version '$value' for .NET '$dotnet'." >&2
    exit 1
  fi
done

echo "sdk=$sdk"
echo "runtime=$runtime"
