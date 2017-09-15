---
layout: post
title:  "What to Protect: MCU Security"
date:   2017-09-14 17:21:00 -0600
tags: Zephyr MCU embedded
---
This post is going to focus on some particular security issues in the
embedded space (the IoT space, if you will).  I regularly work with
microcontrollers (MCUs) based on variants of the Cortex-M
architecture.  These are ARM processors that typically have a small
amount of ROM (&frac12;&ndash;1 MiB) and an even smaller amount of RAM
(16&ndash;128 KiB).

Traditionally, security has not been much of a focus on these types of
devices (think toasters, washing machines, and the likes).  However,
with increased connectivity, we are starting to see more and more
security problems with the code in these devices.

Most of these MCUs only have minimal protection type support.
Usually, there is no MMU.  However, many of these Cortex-M devices
have something known as an MPU.  Rather than general virtual memory,
this allows a small number of regions to be defined that can be given
different privileges.  A typical device may have 6-10 of these
regions.  An important question is, given the region constraints, and
limited number of them, what is the best use of them.

## Regions

Before exploring what to protect, I want to explain a little detail
about how the regions work.  Unlike an MMU, where memory is divided
into pages of a fixed size (or a few fixed sizes), the regions can
individually be sized.  However, whatever size is chosen, that value
must also be used as the alignment of the regions.  The size must also
generally be a power of two.  For example, if a region was made to be
8K in length, the base of the region must be on an 8K boundary.

This is done to keep the hardware implementation simple enough to
prevent an impact on performance.  Restricting the size and alignment
to a power of two allows the implementation to be configured to just
look at a given number of the upper bits of the address (ignoring the
lower bits).

## General OS protection

Memory protection is a common feature in operating systems.  A typical
general-purpose operating system will use memory protection to isolate
each process from each other, as well as the process from the
operating system itself.

In the world of small MCUs, this isn't really something that can be
done in the general case.  It may work for specific hard-coded cases,
say with two processes and a kernel.  But, even building the
application becomes complicated because of the size and alignment
constraints on the regions.

It is possible to treat the small number of regions as if they were a
TLB.  One or two regions would be used for the kernel so that it was
always available (perhaps in supervisor mode).  The rest of memory
would then be unavailable (causing a fault when accessed).  The fault
handler would then chose one of the other regions, and creating a
mapping, similar to how a page fault would be handled on another
platform.  This would allow a more general purpose solution.

However, this has a few distinct disadvantages on an MCU:
- These MCUs are generally fairly slow.  50-120MHz is common.  Taking
  a bunch of time to handle page faults will make them even less
  performant.
- More significantly, introducing page faults will make the code
  execution less predictable.  Since these devices often need to
  communicate with hardware, predictable performance is important.

## Protecting secrets

Instead of general protection, what I think would be useful would be
to choose specific things to protect.  A good example would be device
secrets.  Since most of these devices also don't have a way of storing
secrets, the secrets will have to be placed in normal flash or RAM.
The MPU could be programmed to prevent reads from this secret area.
Code that needs to access it would have to make calls that turn on and
off the protection.

It can be argued that an attack could just make these same calls to
disable the MPU.  This is certainly true.  However, this does protect
against many types of attacks, for example, a network stack bug that
allows reads from arbitrary addresses would be prevented from reading
the secret (think of [HeartBleed][heartbleed]).

## Future

The hope is that future hardware designs will incorporate more
powerful protection that can allow information to be protected better.
However, when designing with existing devices and their limitations,
it is important to determine where it is important to focus efforts.

[heartbleed]: https://en.wikipedia.org/wiki/Heartbleed
