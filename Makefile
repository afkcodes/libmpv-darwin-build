# Path to the Xcode.app bundle. If not set, the overlay will fall back to
# fetching Xcode from the Nix store (requires manual download, see
# nix/overlays/xcode.nix for instructions).
# Example: make XCODE_PATH=/Applications/Xcode_16.1.0.app
XCODE_PATH ?=

# Version string to build. If not set, falls back to .nix/config/version.txt.
# Example: make VERSION=0.0.1
VERSION ?=

# Flake output attribute to build. Set to empty to build the default package
# (the full cross matrix).
# Example: make TARGET=mk-out-archive-libs-macos-universal-video-default
#
# This fork exists for exactly one artifact: the iOS `audio`/`default`
# xcframeworks bundle that rn-media pins. Upstream's default target walks the
# whole matrix (libs + xcframeworks, ios/macos, audio + video,
# default/full/encodersgpl — roughly 40 archives), which is hours of macos-15
# runner time producing 39 archives nobody here consumes, so the default is
# narrowed. The release asset name is derived from the target's own
# os/arch/variant/flavor and is therefore unchanged.
TARGET ?= mk-out-archive-xcframeworks-ios-universal-audio-default

all: build

# Build using Nix flakes.
# After the build, .nix/config/xcode.path and .nix/config/version.txt are
# restored to their committed values.
.PHONY: build
build:
	trap 'git checkout -- .nix/config/xcode.path .nix/config/version.txt' EXIT; \
	$(if $(XCODE_PATH),echo '$(XCODE_PATH)' > .nix/config/xcode.path;,) \
	$(if $(VERSION),echo '$(VERSION)' > .nix/config/version.txt;,) \
	nix build -v -L \
		--option sandbox true \
		--option sandbox-fallback false \
		$(if $(XCODE_PATH),--option extra-sandbox-paths $(XCODE_PATH),) \
		$(if $(TARGET),.#$(TARGET),)
