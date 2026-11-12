#!/bin/bash
sh .devcontainer/linux/import-gpg-keys.sh "${1}"
dotnet restore
