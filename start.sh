#!/bin/bash

# references:
# - https://www.youtube.com/watch?v=AAfFewePE7c

# assumptions
# - pipewire for audio (https://wiki.archlinux.org/title/PipeWire)
# - bridge 'br0' configured with netctl (https://wiki.archlinux.org/title/Bridge_with_netctl)

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

machine=$(read_config ".machine" "q35")
cpus=$(read_config ".cpus")
memory=$(read_config ".memory")

stage=$(read_config ".current_stage" "")
errcho "stage: $stage"

args=()
args+=(
  '-enable-kvm'
  '-machine' "type=$machine"
)

# https://blog.wikichoon.com/2014/07/enabling-hyper-v-enlightenments-with-kvm.html
# https://web.archive.org/web/20131102154932/https://www.linux-kvm.org/wiki/images/0/0a/2012-forum-kvm_hyperv.pdf
enlightenments=$(read_config ".enlightenments" "false")
if [[ "$enlightenments" == "true" ]]; then
  args+=(
    '-cpu' 'host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time'
  )
else
  args+=(
    '-cpu' 'host'
  )
fi

args+=(
  '-smp' "$cpus"
  '-m' "$memory"

  # display
  '-vga' 'virtio'
  '-display' 'sdl,gl=on'

  '-drive' "file=$image,media=disk"
  '-boot' 'menu=on'
  '-monitor' 'stdio'
)

# audio
audio=$(read_config ".audio" "intel-hd")
if [[ "$audio" == "intel-hd" ]]; then
  args+=(
    '-audiodev' 'pipewire,id=snd0'
    '-device' 'ich9-intel-hda'
    '-device' 'hda-output,audiodev=snd0'
  )
elif [[ "$audio" == "ac97" ]]; then
  args+=(
    '-audiodev' 'pipewire,id=snd0'
    '-device' 'AC97,audiodev=snd0'
  )
else
  errcho "invalid .audio, must be one of intel-hd,ac97"
  exit 1;
fi

# network
network=$(read_config ".network" "")
if [[ "$network" == "legacy" ]]; then
  args+=(
    '-netdev' 'user,id=lan0'
    '-device' 'rtl8139,netdev=lan0'
  )
fi

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
