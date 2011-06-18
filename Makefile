# baselayout Makefile
# Copyright 2006-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#
# We've moved the installation logic from Gentoo ebuild into a generic
# Makefile so that the ebuild is much smaller and more simple.
# It also has the added bonus of being easier to install on systems
# without an ebuild style package manager.

PV = $(shell cat .pv)
PKG = baselayout-$(PV)

DESTDIR =
LIB = lib

INSTALL_DIR    = install -m 0755 -d
INSTALL_EXE    = install -m 0755
INSTALL_FILE   = install -m 0644
INSTALL_SECURE = install -m 0600

ifeq ($(OS),)
OS=$(shell uname -s)
ifneq ($(OS),Linux)
OS=BSD
endif
endif

KEEP_DIRS-Linux += \
	/dev \
	/sys
KEEP_DIRS = $(KEEP_DIRS-$(OS)) \
	/boot \
	/etc/profile.d \
	/home \
	/mnt \
	/proc \
	/root \
	/usr/local/bin \
	/usr/local/sbin \
	/usr/local/share/doc \
	/usr/local/share/man \
	/var/empty \
	/var/lock \
	/var/run

all:

clean:

install:
	# These dirs may not exist from prior versions
	for x in $(BASE_DIRS) ; do \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || exit $$? ; \
	done

	$(INSTALL_DIR) $(DESTDIR)/etc
	cp -pPR etc/* etc.$(OS)/* $(DESTDIR)/etc/
	$(INSTALL_DIR) $(DESTDIR)/usr/share/baselayout
	cp -pPR share.$(OS)/* $(DESTDIR)/usr/share/baselayout/

layout:
	# Create base filesytem layout
	for x in $(KEEP_DIRS) ; do \
		test -e $(DESTDIR)$$x/.keep && continue ; \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || echo "ignoring touch failure; mounted fs?" ; \
	done
	# Special dirs
	install -m 0700 -d $(DESTDIR)/root
	touch $(DESTDIR)/root/.keep
	install -m 1777 -d $(DESTDIR)/var/tmp
	touch $(DESTDIR)/var/tmp/.keep
	install -m 1777 -d $(DESTDIR)/tmp
	touch $(DESTDIR)/tmp/.keep
	# FHS compatibility symlinks stuff
	ln -snf /var/tmp $(DESTDIR)/usr/tmp
	ln -snf share/man $(DESTDIR)/usr/local/man

diststatus:
	@if [ -z "$(PV)" ] ; then \
		printf '\nrun: make dist PV=...\n\n'; \
		exit 1; \
	fi
	if test -d .svn ; then \
		svnfiles=`svn status 2>&1 | egrep -v '^(U|P)'` ; \
		if test "x$$svnfiles" != "x" ; then \
			echo "Refusing to package tarball until svn is in sync:" ; \
			echo "$$svnfiles" ; \
			echo "make distforce to force packaging" ; \
			exit 1 ; \
		fi \
	fi 

distlive:
	rm -rf /tmp/$(PKG)
	cp -r . /tmp/$(PKG)
	tar jcf /tmp/$(PKG).tar.bz2 -C /tmp $(PKG) --exclude=.svn
	rm -rf /tmp/$(PKG)
	ls -l /tmp/$(PKG).tar.bz2

distsvn:
	rm -rf $(PKG)
	svn export -q . $(PKG)
	echo $(PV) > $(PKG)/.pv
	svn log . > $(PKG)/ChangeLog.svn
	tar jcf $(PKG).tar.bz2 $(PKG)
	rm -rf $(PKG)
	ls -l $(PKG).tar.bz2

dist: diststatus distsvn

.PHONY: all clean install layout dist distforce diststatus

# vim: set ts=4 :
