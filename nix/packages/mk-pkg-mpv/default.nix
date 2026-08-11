{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
  variant ? import ../../utils/default/variant.nix,
}:

let
  name = "mpv";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  variants = import ../../utils/constants/variants.nix;
  oses = import ../../utils/constants/oses.nix;
  callPackage = pkgs.lib.callPackageWith {
    inherit
      pkgs
      os
      arch
      variant
      ;
  };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };
  xctoolchainLipo = callPackage ../../utils/xctoolchain/lipo.nix { };
  ffmpeg = callPackage ../mk-pkg-ffmpeg/default.nix { };
  libplacebo = callPackage ../mk-pkg-libplacebo/default.nix { };
  uchardet = callPackage ../mk-pkg-uchardet/default.nix { };
  libass = callPackage ../mk-pkg-libass/default.nix { };

  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
    xctoolchainLipo
  ];

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  patchedSource = pkgs.runCommand "${pname}-patched-source-${variant}-${version}" { } ''
    cp -r ${src} src
    export src=$PWD/src
    chmod -R 777 $src

    # rn-media parity release, item 5. Two flags, on EVERY patch in the series.
    #
    # --fuzz=0 is ARCHITECTURE.md 11: GNU patch defaults to --fuzz=2, and a
    # patch that applies with fuzz applies QUIETLY WRONG -- it will happily
    # land a hunk in the wrong place on an already-fixed tree and report
    # success. Only the prefetch-hook line passed it before; the rest of the
    # series ran at the default. git apply (which the Android fork uses) has no
    # fuzz at all, so this is also what makes the two forks apply the same
    # patches under the same rules.
    #
    # --no-backup-if-mismatch stops patch from dropping .orig files into the
    # source tree, which would otherwise end up copied into $out.
    patchflags="--fuzz=0 --no-backup-if-mismatch"

    cd $src
    # Export control -- the one thing the waf -> meson move silently took away,
    # and which mpv 0.41 needs on Apple for the first time because libplacebo
    # enters the link as a static archive. See ./mpv.exp for the list itself.
    #
    # The flag is added to `library('mpv', ...)`'s own link_args by the patch
    # below rather than to the cross file's `*_link_args`, and that distinction
    # cost a CI run: meson feeds the built-in link args to every compiler check
    # too, so an export list naming only `_mpv_*` made
    # `dependency('appleframeworks', modules: ['Foundation', 'AudioToolbox'])`
    # fail its link probe and took the AudioUnit AO out of the build
    # ("Run-time dependency appleframeworks found: NO", CI run 31460332314).
    # Scoping it to the one link that ships is both correct and narrower.
    cp ${./mpv.exp} $src/rn-media-mpv.exp
    patch -p1 $patchflags <${../../../patches/mpv-rn-media-export-list.patch}
    patch -p1 $patchflags <${../../../patches/mpv-fix-missing-objc.patch}
    patch -p1 $patchflags <${../../../patches/mpv-audiounit-shared-session.patch}
    if [ "${variant}" == "${variants.audio}" ]; then
      patch -p1 $patchflags <${../../../patches/mpv-remove-libass.patch}
    fi
    # rn-media: the PCM tap behind `Player.visualizer`. Applied for every
    # variant — it is four files, no build-system files, and the same patch
    # file the Android fork carries, so the two platforms stay one engine.
    patch -p1 $patchflags <${../../../patches/mpv-rn-media-pcm-tap.patch}
    # rn-media: the `on_prefetch_load` client hook + the read-only
    # `prefetch-playlist-entry-id` property. mpv's --prefetch-playlist opens the
    # next entry's RAW filename (prefetch_next() calls start_open() directly and
    # never reaches process_hooks()), so a URL-rewriting resolver never sees it
    # and the prefetch is then discarded by open_demux_reentrant()'s strcmp --
    # making prefetch measurably worse than no prefetch for a network queue.
    # Upstream calls that permanent (DOCS/man/options.rst, --prefetch-playlist).
    # Adds no exports: it rides mpv_hook_add/mpv_hook_continue, so ./mpv.exp is
    # unchanged at 54 names. Byte-identical to the Android fork's
    # buildscripts/patches/mpv/006.rn_media_prefetch_hook.patch, same as the
    # pcm-tap patch above -- one engine, one patch file. No hash inlined here on
    # purpose: an earlier revision pinned this file's OWN sha256, a
    # self-referential check that can never fail, and the copies drifted the
    # same day (prose only; the diff bodies stayed identical). The canonical copy
    # lives in afkcodes/rn-media-engine (patches/004-prefetch-hook, proven
    # tree-equivalent to this diff in that repo's CI); until the workshop's
    # sync --check lands in this repo's CI, identity with the Android copy is
    # discipline, not enforcement -- sync from the workshop, never edit here.
    #
    patch -p1 $patchflags <${../../../patches/mpv-rn-media-prefetch-hook.patch}
    cd -

    cp -r $src $out
  '';
  fixedSource = callPackage ../../utils/patch-shebangs/default.nix {
    name = "${pname}-fixed-source-${variant}-${version}";
    src = patchedSource;
    inherit nativeBuildInputs;
  };
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${variant}-${version}";
  pname = pname;
  inherit version;
  src = fixedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  inherit nativeBuildInputs;
  buildInputs =
    [
      ffmpeg
      libplacebo
    ]
    ++ pkgs.lib.optionals (variant == "video") [
      uchardet
      libass
    ];
  configurePhase = ''
    DISABLE_ALL_OPTIONS=(
      `# booleans`
      -Dgpl=false `# GPL (version 2 or later) build`
      -Dcplayer=false `# mpv CLI player`
      -Dlibmpv=false `# libmpv library`
      -Dbuild-date=false `# whether to include binary compile time`
      -Dtests=false `# unit tests (development only)`
      -Dfuzzers=false `# fuzzer binaries (development only)`
      -Ddisable-packet-pool=false `# disable packet pool (development only)`

      `# misc features`
      -Dcdda=disabled `# cdda support (libcdio)`
      -Dcplugins=disabled `# C plugins`
      -Ddvbin=disabled `# DVB input module`
      -Ddvdnav=disabled `# dvdnav support`
      -Diconv=disabled `# iconv`
      -Djavascript=disabled `# Javascript (MuJS backend)`
      -Dlcms2=disabled `# LCMS2 support`
      -Dlibarchive=disabled `# libarchive wrapper for reading zip files and more`
      -Dlibavdevice=disabled `# libavdevice`
      -Dlibbluray=disabled `# Bluray support`
      -Dlua=disabled `# Lua`
      -Dpthread-debug=disabled `# pthread runtime debugging wrappers`
      -Drubberband=disabled `# librubberband support`
      -Dsdl2-gamepad=disabled `# SDL2 gamepad input`
      -Duchardet=disabled `# uchardet support`
      -Duwp=disabled `# Universal Windows Platform`
      -Dvapoursynth=disabled `# VapourSynth filter bridge`
      -Dvector=disabled `# GCC vector instructions`
      -Dwin32-smtc=disabled `# Windows System Media Transport Controls`
      -Dwin32-threads=disabled `# win32 native threading`
      -Dx11-clipboard=disabled `# X11 clipboard backend`
      -Dzimg=disabled `# libzimg support (high quality software scaler)`
      -Dzlib=disabled `# zlib`

      `# audio output features`
      -Dalsa=disabled `# ALSA audio output`
      -Daudiounit=disabled `# AudioUnit output for iOS`
      `# NEW in 0.41, value auto, and its dependency (CoreMedia +`
      `# AVFoundation) resolves on iOS as well as macOS -- so left alone it`
      `# silently builds a SECOND audio output into an audio-only engine.`
      `# Ours is audiounit (iOS) / coreaudio (macOS).`
      -Davfoundation=disabled `# AVFoundation audio output`
      -Daudiotrack=disabled `# Android AudioTrack audio output`
      -Daaudio=disabled `# Android AAudio audio output`
      -Dcoreaudio=disabled `# CoreAudio audio output`
      -Djack=disabled `# JACK audio output`
      -Dopenal=disabled `# OpenAL audio output`
      -Dopensles=disabled `# OpenSL ES audio output`
      -Doss-audio=disabled `# OSSv4 audio output`
      -Dpipewire=disabled `# PipeWire audio output`
      -Dpulse=disabled `# PulseAudio audio output`
      -Dsdl2-audio=disabled `# SDL2 audio output`
      -Dsndio=disabled `# sndio audio output`
      -Dwasapi=disabled `# WASAPI audio output`

      `# video output features`
      -Dcaca=disabled `# CACA`
      -Dcocoa=disabled `# Cocoa`
      -Dd3d11=disabled `# Direct3D 11 video output`
      -Ddirect3d=disabled `# Direct3D support`
      -Ddmabuf-wayland=disabled `# dmabuf-wayland video output`
      -Ddrm=disabled `# DRM`
      -Degl=disabled `# EGL 1.4`
      -Degl-android=disabled `# Android EGL support`
      -Degl-angle=disabled `# OpenGL ANGLE headers`
      -Degl-angle-lib=disabled `# OpenGL Win32 ANGLE library`
      -Degl-angle-win32=disabled `# OpenGL Win32 ANGLE Backend`
      -Degl-drm=disabled `# OpenGL DRM EGL Backend`
      -Degl-wayland=disabled `# OpenGL Wayland Backend`
      -Degl-x11=disabled `# OpenGL X11 EGL Backend`
      -Dgbm=disabled `# GBM`
      -Dgl=disabled `# OpenGL context support`
      -Dgl-cocoa=disabled `# gl-cocoa`
      -Dgl-dxinterop=disabled `# OpenGL/DirectX Interop Backend`
      -Dgl-win32=disabled `# OpenGL Win32 Backend`
      -Dgl-x11=disabled `# OpenGL X11/GLX (deprecated/legacy)`
      -Djpeg=disabled `# JPEG support`
      -Dsdl2-video=disabled `# SDL2 video output`
      -Dshaderc=disabled `# libshaderc SPIR-V compiler`
      -Dsixel=disabled `# Sixel`
      -Dspirv-cross=disabled `# SPIRV-Cross SPIR-V shader converter`
      -Dplain-gl=disabled `# OpenGL without platform-specific code (e.g. for libmpv)`
      -Dvdpau=disabled `# VDPAU acceleration`
      -Dvdpau-gl-x11=disabled `# VDPAU with OpenGl/X11`
      -Dvaapi=disabled `# VAAPI acceleration`
      -Dvaapi-drm=disabled `# VAAPI (DRM/EGL support)`
      -Dvaapi-wayland=disabled `# VAAPI (Wayland support)`
      -Dvaapi-win32=disabled `# VAAPI (Windows support)`
      -Dvaapi-x11=disabled `# VAAPI (X11 support)`
      -Dvulkan=disabled `# Vulkan context support`
      -Dwayland=disabled `# Wayland`
      -Dx11=disabled `# X11`
      -Dxv=disabled `# Xv video output`

      `# hwaccel features`
      -Dandroid-media-ndk=disabled `# Android Media APIs`
      -Dcuda-hwaccel=disabled `# CUDA acceleration`
      -Dcuda-interop=disabled `# CUDA with graphics interop`
      -Dd3d-hwaccel=disabled `# D3D11VA hwaccel`
      -Dd3d9-hwaccel=disabled `# DXVA2 hwaccel`
      -Dgl-dxinterop-d3d9=disabled `# OpenGL/DirectX Interop Backend DXVA2 interop`
      -Dios-gl=disabled `# iOS OpenGL ES hardware decoding interop support`
      -Dvideotoolbox-gl=disabled `# Videotoolbox with OpenGL`
      -Dvideotoolbox-pl=disabled `# Videotoolbox with libplacebo`

      `# macOS features`
      -Dmacos-10-15-4-features=disabled `# macOS 10.15.4 SDK Features`
      -Dmacos-11-features=disabled `# macOS 11 SDK Features`
      -Dmacos-11-3-features=disabled `# macOS 11.3 SDK Features`
      -Dmacos-12-features=disabled `# macOS 12 SDK Features`
      -Dmacos-cocoa-cb=disabled `# macOS libmpv backend`
      -Dmacos-media-player=disabled `# macOS Media Player support`
      -Dmacos-touchbar=disabled `# macOS Touch Bar support`
      -Dswift-build=disabled `# macOS Swift build tools`
      -Dswift-flags= `# Optional Swift compiler flags`

      `# manpages`
      -Dhtml-build=disabled `# html manual generation`
      -Dmanpage-build=disabled `# manpage generation`
      -Dpdf-build=disabled `# pdf manual generation`
    )

    COMMON_OPTIONS=(
      `# booleans`
      -Dlibmpv=true `# libmpv library`
      -Dbuild-date=true `# whether to include binary compile time`

      `# rn-media parity release, item 7: iconv is now DISABLED here, matching`
      `# Android, which cannot have it. Decided on evidence, not preference:`
      `#`
      `#   * Android builds at API level 21 (buildscripts/build.sh) and bionic`
      `#     only gained iconv(3) at API 28, so -Diconv=enabled there fails the`
      `#     meson check outright. Getting it would mean raising minSdk to 28 --`
      `#     dropping Android 5 through 8 -- or vendoring GNU libiconv as a new`
      `#     engine dependency. Both are product decisions, not build fixes.`
      `#   * What it costs here is smaller than it looks. mpv reaches iconv`
      `#     through mp_charset_guess()/mp_iconv_to_utf8() for metadata, ICY`
      `#     stream titles, CUE sheets and playlists -- but only when a charset`
      `#     is actually named. --metadata-codepage defaults to empty, in which`
      `#     case mp_iconv_to_utf8() returns the buffer untouched even WITH`
      `#     iconv present, and "auto" needs uchardet, which both forks disable.`
      `#     So with today's options this was inert on iOS.`
      `#`
      `# THE LOSS, stated exactly: rn-media can no longer set`
      `# --metadata-codepage=<explicit charset> and have it applied on iOS. It`
      `# could not do so on Android either, which is the point. To restore it on`
      `# BOTH, vendor libiconv (or raise Android's minSdk to 28) and flip this`
      `# back -- tracked in rn-media task #32.`
    )

    COMMON_VIDEO_OPTIONS=(
      `# misc features`
      -Duchardet=enabled `# uchardet support`
      -Dzlib=enabled `# zlib`

      `# video output features`
      -Dgl=enabled `# OpenGL context support`
      -Dplain-gl=enabled `# OpenGL without platform-specific code (e.g. for libmpv)`
    )

    MACOS_OPTIONS=(
      `# audio output features`
      -Dcoreaudio=enabled `# CoreAudio audio output`

      `# video output features`
      -Dcocoa=enabled `# Cocoa` `# BUG: required in audio mode since v0.36.0`
    )

    MACOS_VIDEO_OPTIONS=(
      `# video output features`
      -Dgl-cocoa=enabled `# gl-cocoa`

      `# hwaccel features`
      -Dvideotoolbox-gl=enabled `# Videotoolbox with OpenGL`
    )

    IOS_OPTIONS=(
      `# audio output features`
      -Daudiounit=enabled `# AudioUnit output for iOS`
    )

    IOS_VIDEO_OPTIONS=(
      `# hwaccel features`
      -Dios-gl=enabled `# iOS OpenGL ES hardware decoding interop support`
    )

    OPTIONS=("''${DISABLE_ALL_OPTIONS[@]}")

    OPTIONS+=("''${COMMON_OPTIONS[@]}")
    if [ "${variant}" == "${variants.video}" ]; then
      OPTIONS+=("''${COMMON_VIDEO_OPTIONS[@]}")
    fi

    if [ "${os}" == "${oses.macos}" ]; then
      OPTIONS+=("''${MACOS_OPTIONS[@]}")
      if [ "${variant}" == "${variants.video}" ]; then
        OPTIONS+=("''${MACOS_VIDEO_OPTIONS[@]}")
      fi
    # iossimulator is a THIRD os value, not a flavour of ios, so an "== ios"
    # test alone leaves the simulator matching neither branch -- it falls
    # through to DISABLE_ALL_OPTIONS and ships with EVERY audio output off.
    # The simulator slice of v0.7.2-rnmedia.5 has no AO at all: its own embedded
    # meson line reads -Daudiounit=disabled -Davfoundation=disabled
    # -Daudiotrack=disabled -Daaudio=disabled -Dcoreaudio=disabled
    # -Dopensles=disabled, so libmpv cannot play audio in the iOS Simulator
    # while the device slice is fine. Found by rn-media-engine's
    # "workshop verify-artifacts"; tracked there as manifest/engine.json
    # repoDivergences/ios-simulator-has-no-audio-output.
    #
    # mk-out-frameworks/default.nix:83 already uses the correct idiom
    # ("== ios" OR "== iossimulator"); this is the same test, and the two files
    # disagreeing is what let it through.
    elif [ "${os}" == "${oses.ios}" ] || [ "${os}" == "${oses.iossimulator}" ]; then
      OPTIONS+=("''${IOS_OPTIONS[@]}")
      if [ "${variant}" == "${variants.video}" ]; then
        OPTIONS+=("''${IOS_VIDEO_OPTIONS[@]}")
      fi
    fi

    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      "''${OPTIONS[@]}" |
      tee configure.log
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build

    # copy configure.log
    mkdir -p $out/share/mpv
    cp configure.log $out/share/mpv/
  '';
}
