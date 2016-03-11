#!/bin/sh

# define PWDHASH and SSHAKEY
. $(dirname $0)/build.cf

: ${PWDHASH=""}
: ${SSHAKEY=""}

umount /mnt/mnt
mdconfig -d -u 0

dd if=/dev/zero of=/mnt/mfsroot bs=1M count=650
mdconfig -a -t vnode -f /mnt/mfsroot

newfs -b 4096 -m 0 -o space /dev/md0
mount /dev/md0 /mnt/mnt

fetch -o - http://mirror.yandex.ru/freebsd/releases/amd64/10.2-RELEASE/base.txz | \
	tar -C /mnt/mnt -xzf -

rm -rf /mnt/mnt/boot
mkdir /mnt/mnt/mnt/mediaboot
ln -s mnt/mediaboot/boot /mnt/mnt/boot

echo "/dev/gpt/mediaboot /mnt/mediaboot    ufs ro  0   0" > /mnt/mnt/etc/fstab
cp /etc/resolv.conf /mnt/mnt/etc/

pkg -c /mnt/mnt install -y minidlna nginx
pkg -c /mnt/mnt clean -a -y

cp -p $(dirname $0)/nginx.conf /mnt/mnt/usr/local/etc/nginx/

sed -i '' 's@^media_dir=/opt@media_dir=/media@' /mnt/mnt/usr/local/etc/minidlna.conf

if [ -n "${PWDHASH}" ]
then
    echo "${PWDHASH}" | /usr/sbin/pw -R /mnt/mnt usermod root -H 0
fi

if [ -n "${SSHAKEY}" ]
then
    mkdir /mnt/mnt/root/.ssh
    cat ${SSHAKEY} > /mnt/mnt/root/.ssh/authorized_keys
fi


cp -p $(dirname $0)/amount/amount /mnt/mnt/usr/local/sbin/
mkdir /mnt/mnt/usr/local/etc/devd
cp $(dirname $0)/amount/amount_devd.conf /mnt/mnt/usr/local/etc/devd/


cat << EOT >> /mnt/mnt/etc/rc.conf
hostname="media.root"
sshd_enable="YES"
ntpd_enable="YES"
ntpd_sync_on_start="YES"
minidlna_enable="YES"
nginx_enable="YES"
ifconfig_em0="SYNCDHCP"
EOT

echo "PermitRootLogin without-password" >> /mnt/mnt/etc/ssh/sshd_config
chroot /mnt/mnt /usr/sbin/zic -l /usr/share/zoneinfo/Europe/Moscow
chroot /mnt/mnt /etc/rc.d/sshd start 2> /dev/null

echo "root: /dev/null" >> /mnt/mnt/etc/mail/aliases
chroot /mnt/mnt /usr/bin/newaliases
chmod a+r /mnt/mnt/etc/mail/aliases.db
