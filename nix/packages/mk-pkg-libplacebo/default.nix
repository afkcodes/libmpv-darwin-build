# libplacebo -- a dependency this fork does not want and cannot avoid.
#
# mpv 0.37.0 removed the `libplacebo` build option and made it an unconditional
# `dependency('libplacebo', version: '>=6.338.2')`. It is not confined to the
# video path: core translation units this audio-only build compiles anyway
# (demux/demux_mkv.c, filters/f_lavfi.c, player/main.c, video/mp_image.c,
# video/sws_utils.c) include its headers, so mpv cannot be configured without
# it. libass CAN be stripped (patches/mpv-remove-libass.patch); libplacebo
# cannot -- the surface is spread through colour-space handling mpv's own core
# uses.
#
# Everything that makes libplacebo big is a GPU backend, and every one of them
# is disabled here: no Vulkan, no OpenGL, no D3D11, no shader compilers, no
# demos, no tests. What is left is the colour/format core.
#
# STATIC, unlike every other dependency in this repo. Deliberate: mk-out-libs
# collects `*.dylib` from each dep, so a shared libplacebo would become an
# eleventh xcframework that every consuming app has to embed and re-sign, for a
# handful of colour-space objects. mpv 0.41's own meson declares
# `default_options: ['default_library=static', 'demos=false']` for this
# dependency, i.e. static is the shape upstream expects, and it is also what the
# Android half of this engine ships. libplacebo is LGPLv2.1+ and it is folded
# into libmpv, which is itself LGPL and dynamically linked into the app, so the
# relink obligation is still satisfied at the framework boundary.
#
# The consequence of static linking is an export leak: libplacebo's public
# symbols are decorated `PL_API __attribute__((visibility("default")))` on every
# non-Windows target regardless of `PL_STATIC` (src/include/libplacebo/config.h.in:71),
# so its ~570 `pl_*` symbols would otherwise land in Mpv.framework's export
# table. mk-pkg-mpv pins the export list with `-Wl,-exported_symbols_list`;
# see nix/packages/mk-pkg-mpv/mpv.exp.
{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libplacebo";
  packageLock = (import ../../../packages.lock.nix).${name};
  fastFloatLock = (import ../../../packages.lock.nix).fastFloat;
  jinjaLock = (import ../../../packages.lock.nix).jinja;
  markupsafeLock = (import ../../../packages.lock.nix).markupsafe;
  vulkanHeadersLock = (import ../../../packages.lock.nix).vulkanHeaders;
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  fastFloat = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-fast-float-source-${fastFloatLock.version}";
    inherit (fastFloatLock) url sha256;
  };
  jinja = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-jinja-source-${jinjaLock.version}";
    inherit (jinjaLock) url sha256;
  };
  markupsafe = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-markupsafe-source-${markupsafeLock.version}";
    inherit (markupsafeLock) url sha256;
  };
  vulkanHeaders = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-vulkan-headers-source-${vulkanHeadersLock.version}";
    inherit (vulkanHeadersLock) url sha256;
  };

  # A GitHub release tarball carries libplacebo's `3rdparty/` submodule
  # directories EMPTY. Only `glad` survives that -- it is the Vulkan/OpenGL
  # loader generator and every GPU backend is disabled here. The other four are
  # vendored; packages.lock.nix records exactly what each is load-bearing for
  # and which CI run proved it. Dropping them into these directory names is the
  # supported wiring, not a hack: libplacebo's own meson.build looks for
  # `3rdparty/<name>` (`fs.is_dir` for fast_float and Vulkan-Headers,
  # meson.build:443-444 for the jinja/markupsafe PYTHONPATH).
  vendoredSource = pkgs.runCommand "${pname}-vendored-source-${version}" { } ''
    cp -r ${src} $out
    chmod -R u+w $out
    mkdir -p $out/3rdparty/fast_float $out/3rdparty/jinja \
             $out/3rdparty/markupsafe $out/3rdparty/Vulkan-Headers
    cp -r ${fastFloat}/. $out/3rdparty/fast_float/
    cp -r ${jinja}/. $out/3rdparty/jinja/
    cp -r ${markupsafe}/. $out/3rdparty/markupsafe/
    cp -r ${vulkanHeaders}/. $out/3rdparty/Vulkan-Headers/
  '';
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = vendoredSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      --default-library=static \
      --wrap-mode=nodownload \
      -Dvulkan=disabled `# GPU backend` \
      -Dvk-proc-addr=disabled `# GPU backend` \
      -Dopengl=disabled `# GPU backend` \
      -Dgl-proc-addr=disabled `# GPU backend (dlopen/dlsym loader)` \
      -Dd3d11=disabled `# GPU backend` \
      -Dshaderc=disabled `# SPIR-V compiler, GPU only` \
      -Dglslang=disabled `# SPIR-V compiler, GPU only` \
      -Dlcms=disabled `# external LittleCMS 2` \
      -Dlibdovi=disabled `# external libdovi` \
      -Dxxhash=disabled `# external libxxhash; internal siphash is used` \
      -Dunwind=disabled `# external libunwind, for crash backtraces` \
      -Ddemos=false \
      -Dtests=false \
      -Dbench=false \
      -Dfuzz=false |
      tee configure.log
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build

    # libplacebo is C++ internally (src/convert.cc) but ships a C API, so its
    # .pc file does not name the C++ runtime. Static-linking it into libmpv
    # therefore leaves the C++ ABI unresolved unless -lc++ is added by hand.
    # Upstream mpv-android and the Android half of this engine carry the same
    # one-liner; on Apple `-lc++` resolves to the SDK's libc++.tbd.
    sed -i '/^Libs:/ s|$| -lc++|' $out/lib/pkgconfig/libplacebo.pc

    # copy configure.log
    mkdir -p $out/share/libplacebo
    cp configure.log $out/share/libplacebo/
  '';
}
