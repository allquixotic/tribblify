dnl Process this file with autoconf to produce a configure script.
dnl Created by Anjuta application wizard.

AC_INIT(tribblify, 0.2)

AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11])

AM_SILENT_RULES([yes])

AC_PROG_CC


LT_INIT


dnl Check for vala
AM_PROG_VALAC([0.30.0])


PKG_CHECK_MODULES(TRIBBLIFY,libwnck-3.0
gobject-2.0
gstreamer-1.0
glib-2.0
gmodule-2.0
gstreamer-tag-1.0
gdk-3.0)


AC_OUTPUT([
Makefile
src/Makefile

])
