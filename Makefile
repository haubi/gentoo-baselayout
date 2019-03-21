# baselayout Makefile
# Copyright 2006-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#
# We've moved the installation logic from Gentoo ebuild into a generic
# Makefile so that the ebuild is much smaller and more simple.
# It also has the added bonus of being easier to install on systems
# without an ebuild style package manager.

PV = 2.6
PKG = baselayout-$(PV)
DISTFILE = $(PKG).tar.bz2

CHANGELOG_LIMIT = --after="1 year ago"
INSTALL_DIR    = install -m 0755 -d
INSTALL_EXE    = install -m 0755
INSTALL_FILE   = install -m 0644
INSTALL_SECURE = install -m 0600

# src_configure may find and update these lines, but
# if not, take them from environment, or use fallbacks
OS ?=
EPREFIX ?=

ifeq ($(OS),)
OS=$(shell uname -s)
ifneq ($(OS),Linux)
OS=BSD
endif
endif

KEEP_DIRS-BSD += \
	/var/lock \
	/var/run
KEEP_DIRS-Linux += \
	/dev \
	/run \
	/sys \
	/usr/src
KEEP_DIRS = $(KEEP_DIRS-$(OS)) \
	/boot \
	/etc/profile.d \
	/home \
	/media \
	/mnt \
	/proc \
	/opt \
	/root \
	/usr/local/bin \
	/usr/local/sbin \
	/var/cache \
	/var/empty \
	/var/lib \
	/var/log \
	/var/spool

ETCFILES-BSD += \
	etc.BSD/COPYRIGHT \
	etc.BSD/login.conf
ETCFILES-Linux += \
	etc.Linux/filesystems \
	etc.Linux/inputrc \
	etc.Linux/modprobe.d/aliases.conf \
	etc.Linux/modprobe.d/i386.conf \
	etc.Linux/sysctl.conf
ETCFILES = $(ETCFILES-$(OS)) \
	etc.$(OS)/issue \
	etc.$(OS)/issue.logo \
	etc.$(OS)/os-release \
	etc/env.d/50baselayout \
	etc/hosts \
	etc/networks \
	etc/profile \
	etc/protocols \
	etc/services \
	etc/shells

SHAREFILES-OS += \
	share.$(OS)/fstab \
	share.$(OS)/group
SHAREFILES-BSD += \
	$(SHAREFILES-OS) \
	share.BSD/master.passwd
SHAREFILES-Linux += \
	$(SHAREFILES-OS) \
	share.Linux/issue.devfix \
	share.Linux/passwd \
	share.Linux/shadow
SHAREFILES = $(SHAREFILES-$(OS))

all:

changelog:
	git log ${CHANGELOG_LIMIT} --format=full > ChangeLog

clean:

install:
	test -n '$(DESTDIR)'
	instfiles= ; \
	for srcf in $(ETCFILES) ; do \
		instf=/$${srcf#*/} ; \
		instd=$${instf%/*} ; \
		$(INSTALL_DIR) $(DESTDIR)$(EPREFIX)/etc$${instd} || exit $$?; \
		$(INSTALL_FILE) $${srcf} $(DESTDIR)$(EPREFIX)/etc$${instf} || exit $$?; \
		instfiles="$${instfiles} $(DESTDIR)$(EPREFIX)/etc$${instf}" ; \
	done ; \
	for srcf in $(SHAREFILES) ; do \
		instf=/$${srcf#*/} ; \
		instd=$${instf%/*} ; \
		$(INSTALL_DIR) $(DESTDIR)$(EPREFIX)/usr/share/baselayout$${instd} || exit $$?; \
		$(INSTALL_FILE) $${srcf} $(DESTDIR)$(EPREFIX)/usr/share/baselayout$${instf} || exit $$?; \
		instfiles="$${instfiles} $(DESTDIR)$(EPREFIX)/usr/share/baselayout$${instf}" ; \
	done ; \
	sed -e 's|@GENTOO_PORTAGE_EPREFIX@|$(EPREFIX)|g' \
		-i $${instfiles}

layout-dirs:
	# Create base filesytem layout
	for x in $(KEEP_DIRS) ; do \
		test -e $(DESTDIR)$$x/.keep && continue ; \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || echo "ignoring touch failure; mounted fs?" ; \
	done

layout-BSD: layout-dirs
	-chgrp uucp $(DESTDIR)/var/lock
	install -m 0775 -d $(DESTDIR)/var/lock

layout-Linux: layout-dirs
	ln -snf /proc/self/mounts $(DESTDIR)/etc/mtab
	ln -snf /run $(DESTDIR)/var/run
	ln -snf /run/lock $(DESTDIR)/var/lock

layout: layout-dirs layout-$(OS)
	# Special dirs
	install -m 0700 -d $(DESTDIR)/root
	touch $(DESTDIR)/root/.keep
	install -m 1777 -d $(DESTDIR)/var/tmp
	touch $(DESTDIR)/var/tmp/.keep
	install -m 1777 -d $(DESTDIR)/tmp
	touch $(DESTDIR)/tmp/.keep
	# FHS compatibility symlinks stuff
	ln -snf /var/tmp $(DESTDIR)/usr/tmp

layout-usrmerge: layout
ifeq ($(OS),Linux)
	ln -snf usr/bin ${DESTDIR}/bin
	ln -snf usr/sbin ${DESTDIR}/sbin
	ln -snf bin ${DESTDIR}/usr/sbin
endif

live:
	rm -rf /tmp/$(PKG)
	cp -r . /tmp/$(PKG)
	tar jcf /tmp/$(PKG).tar.bz2 -C /tmp $(PKG) --exclude=.git
	rm -rf /tmp/$(PKG)
	ls -l /tmp/$(PKG).tar.bz2

release:
	git show-ref -q --tags $(PKG)
	git archive --prefix=$(PKG)/ $(PKG) | bzip2 > $(DISTFILE)
	ls -l $(DISTFILE)

snapshot:
	git show-ref -q $(GITREF)
	git archive --prefix=$(PKG)/ $(GITREF) | bzip2 > $(PKG)-$(GITREF).tar.bz2
	ls -l $(PKG)-$(GITREF).tar.bz2

.PHONY: all changelog clean install layout  live release snapshot

# vim: set ts=4 :
