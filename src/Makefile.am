## Process this file with automake to produce Makefile.in

## Created by Anjuta



AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(prefix)/$(DATADIRNAME)/locale"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(datadir)"\" \
	$(TRIBBLIFY_CFLAGS)

AM_CFLAGS =\
	 -Wall\
	 -g

VALAFLAGS =  --pkg gmodule-2.0 --pkg gstreamer-0.10 --pkg gobject-2.0  \
	--pkg libmpdclient

bin_PROGRAMS = tribblify

tribblify_SOURCES = \
	tribblify.vala config.vapi

tribblify_LDFLAGS = \
	-Wl,--export-dynamic

tribblify_LDADD = $(TRIBBLIFY_LIBS)

