#!/bin/bash
 
# Discovers 'manifest.json' files in each image and prints a GitHub Actions matrix as JSON.
# Each image variant gets one matrix entry containing its full tag list.
 
# Usage: build-tag-matrix.sh [root]
#   (root defaults to "src")
 
set -euo pipefail
root="${1:-src}"
 
shopt -s nullglob
manifests=("$root"/*/manifest.json)
 
if [ ${#manifests[@]} -eq 0 ]; then
    echo "No manifest.json files found under $root/" >&2
    exit 1
fi
 
for manifest in "${manifests[@]}"; do
    dir=$(dirname "$manifest")
    jq -c --arg dir "$dir" --arg name "$(basename "$dir")" '
        .version as $version
        | if ($version | type) != "string"
            or ($version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$") | not)
        then error("\($dir): version must look like MAJOR.MINOR.PATCH")
        else . end
        | . as $m
        | ($m.imageName // $name) as $image
        | ($m.variants // []) as $variants
        | ($m.build.latest // $variants[0]) as $latest
        | ($version | split(".")) as $p
        | [$version, "\($p[0]).\($p[1])", $p[0]] as $plain
        | (if ($variants | length) == 0 then [null] else $variants end)[]
        | . as $variant
        | (if $variant == null
            # No variants, just semver + latest
            then $plain + ["latest"]
            # Variants
            else [$plain[] | . + "-" + $variant]
                + (if $variant == $latest then $plain + ["latest"] else [] end)
        end) as $tags
        | {
            image: $image,
            context: $dir,
            variant: ($variant // ""),
            version: $version,
            platforms: ((($m.build.architectures // {})[$variant // ""] // ["linux/amd64", "linux/arm64"]) | join(",")),
            primary: $tags[0],
            tags: ($tags | join(" "))
        }
    ' "$manifest"
done | jq -s -c '{include: .}'
