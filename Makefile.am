## Process this file with automake to produce Makefile.in
## Created by Anjuta

SUBDIRS = src 

tribblifydocdir = ${prefix}/doc/tribblify
tribblifydoc_DATA = \
	README\
	COPYING\
	AUTHORS\
	ChangeLog\
	INSTALL\
	NEWS


EXTRA_DIST = $(tribblifydoc_DATA)


# Remove doc directory on uninstall
uninstall-local:
	-rm -r $(tribblifydocdir)
