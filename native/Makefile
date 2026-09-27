# TCD Store — native build
#
# IMPORTANT: a current Xcode cannot target 10.7. Xcode 15 and later refuse a
# deployment target below macOS 10.13. To actually build a 10.7 binary you
# need Xcode 5.x or 6.x, which run on OS X 10.9-10.10 — which is, to be
# honest, the same vintage of machine this whole project exists for.
#
# If you only have a modern toolchain, build with the floor raised and keep
# the 10.7 calls out of the source; the code is written so that is a
# deployment-target change and nothing more.
#
#   make FLOOR=10.7
#   make FLOOR=10.13      # sanity build on a modern machine
#   make clean

FLOOR      ?= 10.7
BUNDLE_ID  ?= dev.tcd-store.TCDStore
VERSION    ?= 0.1.0
BUILD      ?= build
APP        := $(BUILD)/TCDStore.app
MACOSX_DIRS := $(shell sw_vers -productVersion 2>/dev/null | awk -F. '{print "$$1"."$$2"}')

CC      := clang
SDK     := $(shell xcrun --show-sdk-path)
CFLAGS  := -fobjc-arc -Wall -Wextra -Wno-unused-parameter \
           -mmacosx-version-min=$(FLOOR) -isysroot $(SDK) -O2
LDFLAGS := -framework Cocoa -framework Security \
           -framework CoreFoundation -lsqlite3

SOURCES := $(wildcard TCDStore/*.m)
OBJECTS := $(patsubst TCDStore/%.m,$(BUILD)/%.o,$(SOURCES))

.PHONY: all clean
all: $(APP)

$(APP): $(BUILD)/TCDStore
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	@cp $(BUILD)/TCDStore        $(APP)/Contents/MacOS/TCDStore
	@cp TCDStore/Info.plist      $(APP)/Contents/Info.plist
	@printf 'APPL????' > $(APP)/Contents/PkgInfo
	@echo "built $(APP)  (floor $(FLOOR), SDK $(MACOSX_DIRS))"

$(BUILD)/TCDStore: $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $(OBJECTS) $(LDFLAGS)

$(BUILD)/%.o: TCDStore/%.m
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD)
