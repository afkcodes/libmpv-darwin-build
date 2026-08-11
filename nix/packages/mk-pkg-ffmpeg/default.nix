{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
  variant ? import ../../utils/default/variant.nix,
  flavor ? import ../../utils/default/flavor.nix,
}:

let
  name = "ffmpeg";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  flavors = import ../../utils/constants/flavors.nix;
  variants = import ../../utils/constants/variants.nix;
  callPackage = pkgs.lib.callPackageWith {
    inherit
      pkgs
      os
      arch
      variant
      flavor
      ;
  };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };
  mbedtls = callPackage ../mk-pkg-mbedtls/default.nix { };
  dav1d = callPackage ../mk-pkg-dav1d/default.nix { };
  libxml2 = callPackage ../mk-pkg-libxml2/default.nix { };
  libvorbis = callPackage ../mk-pkg-libvorbis/default.nix { };
  libvpx = callPackage ../mk-pkg-libvpx/default.nix { };
  libx264 = callPackage ../mk-pkg-libx264/default.nix { };

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  patchedSource = pkgs.runCommand "${pname}-patched-source-${variant}-${version}" { } ''
    cp -r ${src} src
    export src=$PWD/src
    chmod -R 777 $src

    cd $src
    # Both remaining patches are VIDEO-ONLY features (a VideoToolbox VP9 decoder
    # wrapper and a GLES 10-bit texture workaround), and both were rebased onto
    # FFmpeg 8.1.2 -- the old files applied only with fuzz, which on 8.1.2 meant
    # silently moving upstream's Vulkan hwaccel out of ff_vp9_decoder. They are
    # gated because the audio variant this fork ships never compiles the files
    # they touch, so applying them there is pure risk.
    #
    # Two patches were DELETED at this bump because 8.1.2 carries the fixes
    # itself, verified in the tree rather than in a changelog:
    #   ffmpeg-fix-dash-base-url-escape -> libavformat/dashdec.c:786,827 already
    #     call xmlEncodeSpecialChars (the patch no longer applies at all).
    #   ffmpeg-fix-hls-mp4-seek -> libavformat/hls.c:2751 already resets
    #     `pls->cur_init_section = NULL` in hls_read_seek. This one is the
    #     dangerous shape: the old patch still applied *with fuzz*, which would
    #     have inserted a second, redundant reset.
    if [ "${variant}" == "${variants.video}" ]; then
      patch -p1 <${../../../patches/ffmpeg-fix-vp9-hwaccel.patch}
      patch -p1 <${../../../patches/ffmpeg-fix-ios-hdr-texture.patch}
    fi
    cd -

    cp ${./meson.build} $src/meson.build
    cp ${./meson.options} $src/meson.options

    cp -r $src $out
  '';
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${variant}-${flavor}-${version}";
  pname = pname;
  inherit version;
  src = patchedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
  ];
  buildInputs =
    [ mbedtls ]
    ++ pkgs.lib.optionals (flavor == flavors.encodersgpl) [
      libvorbis
    ]
    ++ pkgs.lib.optionals (variant == variants.video) [
      dav1d
      libxml2
    ]
    ++ pkgs.lib.optionals (variant == variants.video && flavor == flavors.encodersgpl) [
      libvpx
      libx264
    ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      -Dvariant=${variant} \
      -Dflavor=${flavor} |
      tee configure.log
  '';
  buildPhase = ''
    meson compile -vC build $(basename $src)
  '';
  installPhase = ''
    # manual install to preserve symlinks (meson install -C build)
    cp -r build/dist$out $out

    # copy configure.log
    cp configure.log $out/share/ffmpeg/
  '';
}
