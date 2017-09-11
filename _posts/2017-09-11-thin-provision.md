---
layout: post
title:  "LVM Thinly Provisioned Volumes"
date:   2017-09-11 11:43:00 -0600
tags: backups ubuntu
---
Today, I migrated my primary Ubuntu 17.04 development machine to put
the root volume onto a thinly provisioned volume.  There was a bit of
a comedy of errors, so I want to outline what I should have done, vs
what actually happened.

## What I should have done

As in anything like this, it is important to start with known good
backups.  In my [backup post]({% post_url 2017-09-10-backups %}), I
describe how I'm doing that, and even testing it.  Then things would
roughly following the following steps:

- Back it up again.
- Boot a 17.04 rescue disk.
- lvreduce -r -L 200G ubuntu-vg/root
- Reboot back into system

At this point, I could casually make a new volume, and even test it,
just changing what grub points to, while still having my nice
fallback.

## What actually happened

When I got to the 3rd step above, I left out the `-r` flag to
`lvreduce`.  It might be best to describe this option as &ldquo;Don't
destroy my filesystem&rdquo;, since that seems to be what it does.  I
quickly re-expanded the volume, but fsck was very unhappy with it.
I'm not sure why lvm writes things when you deallocate them, but the
end result was that I got to test my backup recovery process.

### Making the thin volume

It was easy to create the thin volume:
``` bash
lvremove ubuntu-vg/root
lvcreate -L 423g --poolmetadatasize 500m -T ubuntu-vg/thinpool
lvcreate -V 300G -T ubuntu-vg/thinpool -n root
mkfs.ext4 -L root /dev/ubuntu-vg/root
```

A few explanations of the above.  I specified the pool metadata size
because my past experience showed that the default was insufficient
for lots of snapshots.  I determined this value by creating the volume
without the argument, doing an `lvs -a`, and then running the above,
with the amount of metadata doubled.

I discovered partway through the process of restoring data onto this
volume, that Grub2 doesn't support thinly provisioned volumes.  In
order to get past this, I would need to have a boot partition.  I
destroyed all of the lvm logical volumes, and the volume group and
physical volume, and repartitioned the disk, allowing for a 1GB boot
partition.  I put back the swap partition, and created the thin volume
as above, and restored to it.

I edited the destination's /etc/fstab to add an entry for my new
`/boot` partition.  The rest were referred to by LVM volume
identifier, so should be fine on the new system.

### Making it bootable

Grub's configuration tends to use lots of UUIDs to identify
filesystems.  I've also moved my boot partition around.  To help
reinstall this, I would need to rebuild its configuration.

However, before that, there is a problem in that the initrd that
Ubuntu makes doesn't have the thin provisioning tools.  I followed
[these instructions][thinboot], to chroot, and install the thinly
provisioned tools (apt-get works fine in the chroot, by the way, as
long as you copy /etc/resolv.conf into the mounted filesystem).

Before leaving the chroot, I ran the following commands to make sure
everything was updated:
``` bash
update-initramfs -u
grub-install --target x86_64-efi /dev/nvme0n1
update-grub2
```

## Rebooting

After unmounting everything, I tried rebooting the system.  It took
quite a bit longer to boot, but the system does boot up.  A future
task is going to be to figure out how to speed up the boot process.
It seems that the lvm tools are finding lvmetad to not be running,
don't have their caches, and proceed to read every possible drive in
my system, looking for volumes.

Overall, some good lessons learned, and some additional reassurance
that my backup process is recoverable.

[thinboot]: https://www.kubuntuforums.net/showthread.php/68881-Use-thinly-provisioned-LVM-in-Kubuntu
