#!/bin/bash

set -e


######## Modify your Variables ########


GENTOO_RELEASES_URL=http://distfiles.gentoo.org/releases

GENTOO_ARCH=amd64
GENTOO_VARIANT=amd64

TARGET_DISK=/dev/sda

PARTITION_BOOT_SIZE=200M

GRUB_PLATFORMS=pc


######## Variable Assigned ########


echo "### Setting time..."

ntpd -gq

echo "### Creating partitions..."

sfdisk ${TARGET_DISK} << END
size=$PARTITION_BOOT_SIZE,bootable
;
END

echo ""
echo "### Formatting partitions..."

yes | mkfs.ext4 /dev/sda1
yes | mkfs.ext4 /dev/sda2

echo ""
echo "### Labeling partitions..."

e2label /dev/sda1 boot
e2label /dev/sda2 root

echo ""
echo "### Mounting partitions..."


mkdir -p /mnt/gentoo
mount /dev/sda2 /mnt/gentoo

mkdir -p /mnt/gentoo/boot
mount /dev/sda1 /mnt/gentoo/boot

echo "### Setting work directory..."

cd /mnt/gentoo


echo "### Installing stage3..."

STAGE3_PATH_URL=$GENTOO_RELEASES_URL/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_VARIANT.txt
STAGE3_PATH=$(curl -s $STAGE3_PATH_URL | grep -v "^#" | cut -d" " -f1)
STAGE3_URL=$GENTOO_RELEASES_URL/$GENTOO_ARCH/autobuilds/$STAGE3_PATH

wget $STAGE3_URL


echo "##Decompressing Stage3 tarball....."
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner


echo "### Installing kernel configuration..."

#mkdir -p /mnt/gentoo/etc/kernels
#cp -v /etc/kernels/* /mnt/gentoo/etc/kernels

echo "### Copying network options..."

cp -v /etc/resolv.conf /mnt/gentoo/etc/

echo "### Configuring fstab..."

cat >> /mnt/gentoo/etc/fstab << END

# added by gentoo installer

/dev/sda1       /boot       ext4        defaults   0 0
/dev/sda2       /           ext4        defaults   0 0
END


echo""
echo "### Mounting FileSystem....."
mkdir /mnt/gentoo/etc/portage/repos.conf/
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev




echo ""
echo "####################################"
echo "###       Changing root...       ###"
echo "####################################"

cat > /mnt/gentoo/root/gentoo-init.sh << END
#!/bin/bash

set -e

echo "### Upading configuration..."

env-update && source /etc/profile

echo "### Installing portage..."

mkdir -p /etc/portage/repos.conf
cp -f /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
emerge-webrsync

echo "### Installing kernel sources..."

emerge sys-kernel/gentoo-sources

echo ""
echo "### Installing Downloaded Kernel"
echo "sys-apps/util-linux static-libs" > /etc/portage/package.use/genkernel
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" >> /etc/portage/package.license
emerge sys-kernel/genkernel
#--autounmask-write
genkernel all


echo ""
echo "### Installing bootloader..."
emerge --newuse --deep sys-boot/grub:2

cat >> /etc/portage/make.conf << IEND

# added by gentoo installer
GRUB_PLATFORMS="$GRUB_PLATFORMS"
IEND

cat >> /etc/default/grub << IEND

# added by gentoo installer
#GRUB_CMDLINE_LINUX="net.ifnames=0"
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
IEND

echo ""
echo "Compiling Grub...."
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
echo "Grub compiled successfully"

echo ""
echo "### Configuring network..."
emerge net-misc/netifrc
emerge net-misc/dhcpcd

echo ""
echo "### Configuring SSH..."
rc-update add sshd default


echo ""
echo "### Changing root password..."
echo "root:123456" | chpasswd


echo ""
echo "### Configuring cronie....."
emerge sys-process/cronie
rc-update add cronie default


END


chmod +x /mnt/gentoo/root/gentoo-init.sh
chroot /mnt/gentoo /root/gentoo-init.sh

echo "###################################################################################"
echo "###################################################################################"
echo "###################################################################################"
echo ""
echo ""
echo "### Reboot NOw..."

#reboot
