
# create image
qemu-img create -f qcow2 Image.img 10G

# eject CD
info block
eject ide3-cd0
change ide3-cd0 ./iso/cdimage
