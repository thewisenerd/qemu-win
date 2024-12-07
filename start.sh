#!/bin/bash

# references:
# - https://www.youtube.com/watch?v=AAfFewePE7c

set -euo pipefail

function errcho() {
  echo "$@" >&2;
}

if [[ $# -ne 1 ]]; then
  errcho "usage: $0 <cfg>"
  exit 1;
fi

cfg="$1"
if [[ ! -e "config/$cfg.yaml" ]]; then
  errcho "config/<cfg>.yaml must exist"
  exit 1;
fi

function read_config() {
  out=$(cat "config/$cfg.yaml" | yq -e -r -c "$1")
  if [[ $? -ne 0 ]]; then
    if [[ $# -ne 2 ]]; then
      errcho "required key '$1' not found"
      exit 1
    fi

    errcho "defaulting to '$2' for key '$1'"
    echo "$2"
  else
    echo "$out"
  fi
}

image=$(read_config ".image")
size=$(read_config ".size" "24G")

if [[ ! -e "$image" ]]; then
  errcho "creating image '$image' ($size)"
  qemu-img create -f qcow2 "$image" "$size"
fi

cpus=$(read_config ".cpus")
memory=$(read_config ".memory")

stage=$(read_config ".current_stage" "")
errcho "stage: $stage"

args=()
args+=(
  '-enable-kvm'
  '-machine' 'type=q35'
  '-cpu' 'host'
  '-smp' "$cpus"
  '-m' "$memory"

  # display
  '-vga' 'virtio'
  '-display' 'sdl,gl=on'

  '-drive' "file=$image,media=disk"
  '-boot' 'menu=on'
  '-monitor' 'stdio'

  # audio
  '-audiodev' 'pipewire,id=snd0'
  '-device' 'ich9-intel-hda'
  '-device' 'hda-output,audiodev=snd0'
)

if [[ -n "$stage" ]]; then
  isos=$(read_config ".stages[\"$stage\"].isos" "")
  if [[ -n "$isos" ]]; then
    for iso in $(echo "$isos" | yq -rc '.[]'); do
      errcho "  mounting iso: '$iso'"
      args+=(
        '-drive' "file=$iso,media=cdrom"
      )
    done
  fi
fi

errcho "adding blank cdrom for further usage";
args+=(
  '-drive' 'media=cdrom'
)

errcho "booting with args: ${args[@]}"

exec qemu-system-x86_64 "${args[@]}"
