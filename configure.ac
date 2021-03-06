AC_PREREQ([2.63])
AC_INIT([GNOME Mahjongg], [3.22.0], [https://bugzilla.gnome.org/],
        [gnome-mahjongg], [https://wiki.gnome.org/Apps/Mahjongg])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE

AM_PROG_VALAC([0.24.0])
AM_PROG_CC_C_O

GLIB_GSETTINGS

APPSTREAM_XML

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40.0
GTK_REQUIRED=3.13.2
RSVG_REQUIRED=2.32.0

PKG_CHECK_MODULES(GNOME_MAHJONGG, [
  glib-2.0 >= $GLIB_REQUIRED
  gio-2.0
  gtk+-3.0 >= $GTK_REQUIRED
  librsvg-2.0 >= $RSVG_REQUIRED
])

GLIB_COMPILE_RESOURCES=`$PKG_CONFIG --variable glib_compile_resources gio-2.0`
AC_SUBST(GLIB_COMPILE_RESOURCES)

AC_PATH_PROG([DESKTOP_FILE_VALIDATE], [desktop-file-validate], [/bin/true])

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL([0.50])
AC_SUBST(GETTEXT_PACKAGE, gnome-mahjongg)

dnl ###########################################################################
dnl Documentation
dnl ###########################################################################

YELP_HELP_INIT

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
po/Makefile.in
data/Makefile
data/icons/Makefile
data/icons/hicolor/Makefile
help/Makefile
src/Makefile
])
AC_OUTPUT
