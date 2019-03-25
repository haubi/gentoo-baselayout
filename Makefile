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
ROOT ?=
BROOT ?=
# fallback support for EAPI 6 environment
BROOT ?= $(PORTAGE_OVERRIDE_EPREFIX)

ifeq ($(OS),)
OS=$(shell uname -s)
ifneq ($(OS),Linux)
OS=BSD
endif
endif

KEEP_DIRS-OS += \
	/boot \
	/home \
	/media \
	/mnt \
	/opt \
	/proc \
	/root
KEEP_DIRS-BSD += \
	$(KEEP_DIRS-OS) \
	/var/lock \
	/var/run
KEEP_DIRS-Linux += \
	$(KEEP_DIRS-OS) \
	/dev \
	/run \
	/sys \
	/usr/src
KEEP_DIRS = $(KEEP_DIRS-$(OS)) \
	/etc/profile.d \
	/usr/local/bin \
	/usr/local/sbin \
	/var/cache \
	/var/empty \
	/var/lib \
	/var/log \
	/var/spool

ETCFILE-OS += \
	etc.$(OS)/issue \
	etc.$(OS)/issue.logo \
	etc.$(OS)/os-release \
	etc/hosts \
	etc/networks \
	etc/protocols \
	etc/services \
	etc/shells
ETCFILES-BSD += \
	$(ETCFILE-OS) \
	etc.BSD/COPYRIGHT \
	etc.BSD/login.conf
ETCFILES-Linux += \
	$(ETCFILE-OS) \
	etc.Linux/filesystems \
	etc.Linux/inputrc \
	etc.Linux/modprobe.d/aliases.conf \
	etc.Linux/modprobe.d/i386.conf \
	etc.Linux/sysctl.conf
ETCFILES-prefix-guest += \
	gen-etc.$(OS)/env.d/99host
ETCFILES-prefix-stack += \
	$(ETCFILES-prefix-guest) \
	gen-etc.prefix-stack/env.d/00host
ETCFILES = $(ETCFILES-$(OS)) \
	etc/env.d/50baselayout \
	gen-etc.$(OS)/gentoo-release \
	etc/profile

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

gen-etc.Linux/gentoo-release gen-etc.BSD/gentoo-release:
	$(INSTALL_DIR) $(@D)
	echo "Gentoo Base System release $(PV)" > $@

gen-etc.prefix-guest/gentoo-release:
	$(INSTALL_DIR) $(@D)
	echo "Gentoo Prefix Base System release $(PV)" > $@

gen-etc.prefix-stack/gentoo-release:
	$(INSTALL_DIR) $(@D)
	echo "Gentoo Prefix Stack Base System release $(PV)" > $@

gen-etc.prefix-guest/env.d/99host:
	# Define PATH,MANPATH for host system
	$(INSTALL_DIR) $(@D)
	{ echo PATH=/usr/sbin:/usr/bin:/sbin:/bin \
	; ! test -d '$(ROOT)/usr/share/man' || echo MANPATH=/usr/share/man \
	; } > $@

gen-etc.prefix-stack/env.d/99host:
	# Query PATH,MANPATH from base prefix
	$(INSTALL_DIR) $(@D)
	sed -n -E '/^export (PATH|MANPATH)=/{s/^export //;p}' '$(BROOT)'/etc/profile.env > $@

gen-etc.prefix-stack/env.d/00host:
	# Query EDITOR,PAGER from base prefix
	$(INSTALL_DIR) $(@D)
	sed -n -E '/^export (EDITOR|PAGER)=/{s/^export //;p}' '$(BROOT)'/etc/profile.env > $@

install: $(ETCFILES) $(SHAREFILES)
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
		test -e $(DESTDIR)$(EPREFIX)$$x/.keep && continue ; \
		$(INSTALL_DIR) $(DESTDIR)$(EPREFIX)$$x || exit $$? ; \
		touch $(DESTDIR)$(EPREFIX)$$x/.keep || echo "ignoring touch failure; mounted fs?" ; \
	done

layout-$(OS): layout-dirs

layout-OS:
	# Special dirs
	install -m 0700 -d $(DESTDIR)$(EPREFIX)/root
	touch $(DESTDIR)$(EPREFIX)/root/.keep

layout-BSD: layout-OS
	-chgrp uucp $(DESTDIR)$(EPREFIX)/var/lock
	install -m 0775 -d $(DESTDIR)$(EPREFIX)/var/lock

layout-Linux: layout-OS
	ln -snf /proc/self/mounts $(DESTDIR)$(EPREFIX)/etc/mtab
	ln -snf /run $(DESTDIR)$(EPREFIX)/var/run
	ln -snf /run/lock $(DESTDIR)$(EPREFIX)/var/lock

layout: layout-$(OS)
	# Special dirs
	install -m 1777 -d $(DESTDIR)$(EPREFIX)/var/tmp
	touch $(DESTDIR)$(EPREFIX)/var/tmp/.keep
	install -m 1777 -d $(DESTDIR)$(EPREFIX)/tmp
	touch $(DESTDIR)$(EPREFIX)/tmp/.keep
	# FHS compatibility symlinks stuff
	ln -snf $(EPREFIX)/var/tmp $(DESTDIR)$(EPREFIX)/usr/tmp

layout-usrmerge: layout
ifneq ($(OS),BSD)
	# usrmerge symlinks
	$(INSTALL_DIR) $(DESTDIR)$(EPREFIX)/usr/bin
	ln -snf usr/bin $(DESTDIR)$(EPREFIX)/bin
	ln -snf usr/sbin $(DESTDIR)$(EPREFIX)/sbin
	ln -snf bin $(DESTDIR)$(EPREFIX)/usr/sbin
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
