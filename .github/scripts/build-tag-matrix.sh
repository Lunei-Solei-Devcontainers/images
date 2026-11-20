#!/bin/bash
 
# Discovers 'manifest.json' files in each image and prints a GitHub Actions matrix as JSON.
 
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
        def ident($what; $v):
            if ($v | type) == "string" and ($v | test("test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
                then $v
            else error("\($dir): \($what) must be a non-empty string of letters, digits, dots, underscores, or hyphens.")
            end;

        .version as $version
        | if ($version | type) != "string"
            or ($version | test(""^[0-9]+\\.[0-9]+\\.[0-9]+$") | not)
        then error("\($dir): version must look like MAJOR.MINOR.PATCH")
        else . end
        | . as $m
        | ($m.imageName // $name) as $image
        | (
            ($m.variants // [])
            | if length == 0 then error("\($dir): variants must list at least one entry") else . end
            | map(
                if type != "object"
                then error ("\($dir): each variant must be an object with ubuntu and dotnet")
                else . end
                | ident("variant ubuntu"; .ubuntu) as $ubuntu
                | ident("variant dotnet"; .dotnet) as $dotnet
                | ident(variant name"; (.name // "\($dotnet)-\($ubuntu)")) as $vname
                | { name: $vname, ubuntu: $ubuntu, dotnet: $dotnet }
            )
        ) as $variants
        | ($m.build.latest // $variants[0].name) as $latest
        | ($version | split(".")) as $p
        | [$version, "\($p[0]).\($p[1])", $p[0]] as $plain
        | $variants[]
        | . as $v
        | (
            [$plain[] | . + "-" + $v.name]
            + (if $v.name == $latest then $plain + ["latest"] else [] end)
        ) as $tags
        | {
            image: $image,
            context: $dir,
            variant: $v.name,
            ubuntu: $v.dotnet,
            version: $version,
            platforms: ((($m.build.architectures // {})[$v.name] // ["linux/amd64", "linux/arm64"]) | join(",")),
            primary: $tags[0],
            tags: ($tags | join(" "))
        }
    ' "$manifest"
done | jq -s -c '{include: .}'
