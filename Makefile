# baselayout Makefile
# Copyright 2006-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#
# We've moved the installation logic from Gentoo ebuild into a generic
# Makefile so that the ebuild is much smaller and more simple.
# It also has the added bonus of being easier to install on systems
# without an ebuild style package manager.

SUBDIRS = etc share

NAME = baselayout
VERSION = 2.0.0

PKG = $(NAME)-$(VERSION)

ifeq ($(OS),)
OS=$(shell uname -s)
ifneq ($(OS),Linux)
OS=BSD
endif
endif

KEEP_DIRS = /boot /home /mnt /root /proc \
	/usr/local/bin /usr/local/sbin /usr/local/share/doc /usr/local/share/man \
	/var/lock /var/run /var/empty

ifeq ($(OS),Linux)
	KEEP_DIRS += /dev /sys
endif

TOPDIR = .
include $(TOPDIR)/default.mk

install::
	# These dirs may not exist from prior versions
	for x in $(BASE_DIRS) ; do \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || exit $$? ; \
	done

layout:
	# Create base filesytem layout
	for x in $(KEEP_DIRS) ; do \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || exit $$? ; \
	done
	# Special dirs
	install -m 0700 -d $(DESTDIR)/root || exit $$?
	touch $(DESTDIR)/root/.keep || exit $$?
	install -m 1777 -d $(DESTDIR)/var/tmp || exit $$?
	touch $(DESTDIR)/var/tmp/.keep || exit $$?
	install -m 1777 -d $(DESTDIR)/tmp || exit $$?
	touch $(DESTDIR)/tmp/.keep || exit $$?
	# FHS compatibility symlinks stuff
	ln -snf /var/tmp $(DESTDIR)/usr/tmp || exit $$?
	ln -snf share/man $(DESTDIR)/usr/local/man || exit $$?

diststatus:
	if test -d .svn ; then \
		svnfiles=`svn status 2>&1 | egrep -v '^(U|P)'` ; \
		if test "x$$svnfiles" != "x" ; then \
			echo "Refusing to package tarball until svn is in sync:" ; \
			echo "$$svnfiles" ; \
			echo "make distforce to force packaging" ; \
			exit 1 ; \
		fi \
	fi 

distforce:
	rm -rf /tmp/$(PKG)
	svn export -q . /tmp/$(PKG)
	tar jcf /tmp/$(PKG).tar.bz2 -C /tmp $(PKG)
	rm -rf /tmp/$(PKG)
	ls -l /tmp/$(PKG).tar.bz2

dist: diststatus distforce

.PHONY: layout dist distforce diststatus

# vim: set ts=4 :
