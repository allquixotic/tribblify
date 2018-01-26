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

tribblify_VALAFLAGS = $(AM_VALAFLAGS) --pkg glib-2.0 --pkg gmodule-2.0 --pkg gstreamer-1.0 --pkg gstreamer-tag-1.0 --pkg gobject-2.0  \
	--pkg libwnck-3.0 --pkg gdk-3.0 --pkg libsoup-2.4

bin_PROGRAMS = tribblify

tribblify_SOURCES = \
	tribblify.vala http-control.vala config.vapi Makefile.am

tribblify_CFLAGS = -DWNCK_I_KNOW_THIS_IS_UNSTABLE=1

tribblify_LDFLAGS = \
	-Wl,--export-dynamic

tribblify_LDADD = $(TRIBBLIFY_LIBS)

