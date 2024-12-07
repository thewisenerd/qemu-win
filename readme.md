qemu-win
========

running windows VMs with qemu directly.

# choices
- default QEMU networking [ref][qemu-net-ref]
- assumptions
  - pipewire for audio
- todo
  - [ ] TAP networking
  - [ ] win10
    - [ ] virtio drivers, multi-stage

[qemu-net-ref]: https://wiki.qemu.org/Documentation/Networking

# notes

## eject / replace CD

```
info block
eject ide3-cd0
change ide3-cd0 ./iso/cdimage
```
