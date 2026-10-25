# Sonda Teams - mała aplikacja testowa dla iOS 6 (jailbreak), budowana w Theosie.
# Sprawdza, czy telefon dogada się przez HTTPS z serwerami Microsoftu (logowanie i Graph).
SDKVER ?= 6.1

# armv7 działa na iPhone 3GS/4/4S/5 i iPod touch 4/5 (iOS 6.x)
export ARCHS = armv7
export TARGET = iphone:clang:$(SDKVER):6.0

# stary dpkg z iOS 6 nie czyta nowszej kompresji niż gzip
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

INSTALL_TARGET_PROCESSES = TeamsProbe

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TeamsProbe

TeamsProbe_FILES = main.m AppDelegate.m TPCrash.m TPProbe.m TPController.m tp_libc.c
TeamsProbe_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore Security
TeamsProbe_CFLAGS = -fobjc-arc -fno-stack-protector -D_FORTIFY_SOURCE=0 -Wno-deprecated-declarations -Wno-unused-command-line-argument

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache"
