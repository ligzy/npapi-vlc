###############################################################################
# Building the Mozilla plugin
###############################################################################

EXTRA_DIST = package/npvlc_rc.rc.in package/npvlc.dll.manifest
MOSTLYCLEANFILES =
CLEANFILES = $(BUILT_SOURCES)
npvlcdir = $(libdir)/mozilla/plugins

AM_CPPFLAGS = $(LIBVLC_CFLAGS) -Inpapi-sdk $(MOZILLA_CFLAGS)

libvlcplugin_la_SOURCES = \
	common.h \
	events.h \
	events.cpp \
	vlcshell.h \
	vlcshell.cpp \
	vlcplugin.h \
	vlcplugin_base.cpp \
	vlcplugin_base.h \
	control/npolibvlc.cpp \
	control/npolibvlc.h \
	control/nporuntime.cpp \
	control/nporuntime.h \
	../common/position.h \
	support/classinfo.h \
	../common/vlc_player_options.h \
	../common/vlc_player.cpp \
	../common/vlc_player.h \
	$(SOURCES_support)

EXTRA_libvlcplugin_la_SOURCES = \
	support/npwin.cpp support/npmac.cpp support/npunix.cpp

libvlcplugin_la_DEPENDENCIES =
libvlcplugin_la_LIBADD = $(LIBVLC_LIBS)
libvlcplugin_la_LDFLAGS = \
	-module -avoid-version \
	-no-undefined

npvlc_la_SOURCES = $(libvlcplugin_la_SOURCES)
npvlc_la_DEPENDENCIES = $(libvlcplugin_la_DEPENDENCIES)
npvlc_la_LIBADD = $(libvlcplugin_la_LIBADD)
npvlc_la_LDFLAGS = $(libvlcplugin_la_LDFLAGS)

npapi-sdk:
	svn export http://npapi-sdk.googlecode.com/svn/trunk/headers npapi-sdk-svn -r HEAD
	mv npapi-sdk-svn npapi-sdk

if !HAVE_DARWIN
if !HAVE_WIN32

# Unix (x11) platforms
#
npvlc_LTLIBRARIES = libvlcplugin.la

if FETCH_NPAPI
$(libvlcplugin_la_OBJECTS): npapi-sdk
endif

AM_CPPFLAGS += -DXP_UNIX -DDATA_PATH=\"$(pkgdatadir)\"
libvlcplugin_la_LIBADD += $(MOZILLA_LIBS)

SOURCES_support = \
	support/npunix.cpp

if WITH_GTK
AM_CPPFLAGS += $(GTK_CFLAGS)
libvlcplugin_la_LIBADD += $(GTK_LIBS) $(X_LIBS) $(X_PRE_LIBS) -lX11
SOURCES_support += \
	vlcplugin_gtk.cpp \
	vlcplugin_gtk.h
else # !WITH_GTK
AM_CPPFLAGS += $(XCB_CFLAGS)
libvlcplugin_la_LIBADD += $(XCB_LIBS)
SOURCES_support += \
	vlcplugin_xcb.cpp \
	vlcplugin_xcb.h
endif # !USE_GTK

if HAVE_XCB
AM_CPPFLAGS += $(XCB_CFLAGS)
libvlcplugin_la_LIBADD += $(XCB_LIBS)
SOURCES_support += \
	vlcwindowless_xcb.cpp \
	vlcwindowless_xcb.h \
	vlcwindowless_base.cpp \
	vlcwindowless_base.h
endif # !HAVE_XCB

else # Win32

# Under Win32|Mac, Mozilla plugins need to be named NP******.DLL, but under Unix
# the common naming scheme is lib******plugin.so.
#
lib_LTLIBRARIES = npvlc.la

if FETCH_NPAPI
$(npvlc_la_OBJECTS): npapi-sdk
endif

AM_CPPFLAGS += -DXP_WIN -DXP_WIN32 \
	-DXPCOM_GLUE -DHAVE_CPP_MODERN_SPECIALIZE_TEMPLATE_SYNTAX
SOURCES_support = \
	support/npwin.cpp \
	vlcplugin_win.cpp \
	vlcplugin_win.h \
	vlcwindowless_win.cpp \
	vlcwindowless_win.h \
	../common/win32_fullscreen.cpp \
	../common/win32_fullscreen.h \
	../common/win32_vlcwnd.cpp \
	../common/win32_vlcwnd.h

npvlc_la_DEPENDENCIES += $(DATA_npvlc_rc)
npvlc_la_LDFLAGS += -Wl,--kill-at -Wl,$(DATA_npvlc_rc)
npvlc_la_LIBADD += -lgdi32

DATA_npvlc_rc = $(noinst_DATA)
noinst_DATA = npvlc_rc.$(OBJEXT)

npvlc_rc.$(OBJEXT): package/npvlc_rc.rc
	$(WINDRES) --include-dir $(srcdir) -i $< -o $@

endif
else

if FETCH_NPAPI
$(npvlc_la_OBJECTS): npapi-sdk
endif

# MacOS X
# Mac OS plugins need .r files that will be processed into rsrc files
#
lib_LTLIBRARIES = npvlc.la

AM_CPPFLAGS += -I. -I$(top_builddir) -c \
	-DXP_UNIX -DXP_MACOSX=1 \
	-DNO_X11=1 -DUSE_SYSTEM_CONSOLE=1 -pipe -fmessage-length=0

SOURCES_support = support/npmac.cpp \
                  vlcplugin_mac.cpp \
                  vlcplugin_mac.h \
                  vlcwindowless_base.cpp \
                  vlcwindowless_base.h \
                  vlcwindowless_mac.cpp \
                  vlcwindowless_mac.h
libvlcplugin_la_LDFLAGS += \
	-bundle -Wl,-headerpad_max_install_names \
	-Wl,-framework,CoreFoundation -Wl,-framework,ApplicationServices \
	-shrext .dylib

noinst_DATA = VLC\ Plugin.plugin
CLEANFILES += VLC\ Plugin.plugin

#
# Plugin uses shared libraries that are located relatively through @executable_path,
# which unfortunately references the path of the App using the Plugin, rather than the
# Plugin itself. Since this Plugin should always be installed in '/Library/Internet Plug-Ins',
# it is safer to force dylibs to locate dependents through a fixed path
#
define FIXEXECPATH
	otool -L "$$dylib" | \
	awk -v libdylib="$$dylib" ' \
	/@executable_path/ { \
	    newpath=$$1 ; \
	    sub("@executable_path","/Library/Internet Plug-Ins/VLC Plugin.plugin/Contents/MacOS",newpath) ; \
	    print "install_name_tool -change \""$$1"\" \""newpath"\" \""libdylib"\"" ; \
	}' | sh -x
endef

VLC\ Plugin.plugin: $(lib_LTLIBRARIES)
	rm -Rf "$@"
	$(INSTALL) -d "VLC-Plugin.plugin/Contents/MacOS/lib"
	$(INSTALL) -d "VLC-Plugin.plugin/Contents/Resources"
	ACTION="release-makefile" PRODUCT="VLC-Plugin.plugin" libvlc_dir=$(LIBVLC_PREFIX) src_dir=$(srcdir) build_dir=$(top_builddir) sh "$(top_srcdir)/extras/macosx/build-package.sh"
	$(INSTALL) "$(top_builddir)/extras/macosx/Info.plist" "VLC-Plugin.plugin/Contents/Info.plist"
	mv "VLC-Plugin.plugin" "VLC Plugin.plugin"
	find "VLC Plugin.plugin" -type d -exec chmod ugo+rx '{}' \;
	find "VLC Plugin.plugin" -type f -exec chmod ugo+r '{}' \;

# uncomment if dependencies on XPCOM libs is sought
#	if test -d "$(MOZILLA_SDK_PATH)/lib"; then \
#	  for i in "$(MOZILLA_SDK_PATH)"/lib/*.dylib ; do \
#	    dylib="$(srcdir)/$@/Contents/MacOS/`basename $${i}`" ; \
#	    $(INSTALL) -m 644 "$${i}" "$$dylib" ; \
#	    $(FIXEXECPATH); \
#	  done ; \
#	fi

endif # Mac
