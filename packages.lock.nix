{
  dav1d = {
    version = "1.2.1";
    url = "https://code.videolan.org/videolan/dav1d/-/archive/1.2.1/dav1d-1.2.1.tar.bz2";
    sha256 = "a4003623cdc0109dec3aac8435520aa3fb12c4d69454fa227f2658cdb6dab5fa";
  };
  # FFmpeg 8.1.2 ("Hoare" line). The floor is mpv 0.41's own
  # `dependency('libavcodec', version: '>= 60.31.102')` (meson.build:21), i.e.
  # FFmpeg >= 6.1. Deliberately NOT n9.0: that branch was cut six months AFTER
  # mpv 0.41.0 shipped and has no point release yet. The 8.1 line is maintained
  # and is the pairing the Android half of this engine bump also ships, so both
  # platforms run one FFmpeg.
  ffmpeg = {
    version = "8.1.2";
    url = "https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz";
    sha256 = "464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c";
  };
  fftools-ffi = {
    version = "9b0d4da0";
    url = "https://github.com/moffatman/fftools-ffi/archive/9b0d4da026d9c830702ec043c1f1f98d407025af.tar.gz";
    sha256 = "mgf3ddt3yjmYBd2D0WeEnhgxKNjrEbjYnDx2t4YCfU8=";
  };
  freetype = {
    version = "2.13.2";
    url = "https://downloads.sourceforge.net/project/freetype/freetype2/2.13.2/freetype-2.13.2.tar.xz";
    sha256 = "12991c4e55c506dd7f9b765933e62fd2be2e06d421505d7950a132e4f1bb484d";
  };
  fribidi = {
    version = "1.0.13";
    url = "https://github.com/fribidi/fribidi/releases/download/v1.0.13/fribidi-1.0.13.tar.xz";
    sha256 = "7fa16c80c81bd622f7b198d31356da139cc318a63fc7761217af4130903f54a2";
  };
  harfbuzz = {
    version = "8.1.1";
    url = "https://github.com/harfbuzz/harfbuzz/archive/8.1.1.tar.gz";
    sha256 = "b16e6bc0fc7e6a218583f40c7d201771f2e3072f85ef6e9217b36c1dc6b2aa25";
  };
  libass = {
    version = "0.17.1";
    url = "https://github.com/libass/libass/releases/download/0.17.1/libass-0.17.1.tar.xz";
    sha256 = "f0da0bbfba476c16ae3e1cfd862256d30915911f7abaa1b16ce62ee653192784";
  };
  libogg = {
    version = "1.3.5";
    url = "https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz";
    sha256 = "0eb4b4b9420a0f51db142ba3f9c64b333f826532dc0f48c6410ae51f4799b664";
  };
  # libplacebo became a MANDATORY dependency of mpv in 0.37.0: mpv 0.36's
  # meson.build had `option('libplacebo', ...)`, 0.41's has a bare
  # `dependency('libplacebo', version: '>=6.338.2')` (meson.build:29). It is
  # reached from core, non-video translation units (demux/demux_mkv.c,
  # filters/f_lavfi.c, player/main.c, video/mp_image.c, video/sws_utils.c), so
  # unlike libass it cannot be stripped -- see nix/packages/mk-pkg-libplacebo.
  #
  # 6.338.2 is exactly mpv 0.41's declared minimum. NOT 7.x: that drops symbols
  # mpv 0.41's csputils.h still references under mobile cross-files, and the
  # Android half of this engine pins 6.338.2 for the same reason.
  #
  # github.com/haasn (libplacebo's own author, upstream's own mirror) rather
  # than code.videolan.org, which refuses connections from some networks.
  libplacebo = {
    version = "6.338.2";
    url = "https://github.com/haasn/libplacebo/archive/refs/tags/v6.338.2.tar.gz";
    sha256 = "2f1e624e09d72a8c9db70f910f7560e764a1c126dae42acc5b3bcef836a7aec6";
  };
  # Three of libplacebo's five `3rdparty/` submodules, at the exact commits
  # v6.338.2 points at. A GitHub release tarball carries the submodule
  # directories EMPTY, and for `glad` and `Vulkan-Headers` that is fine (they
  # feed the Vulkan/OpenGL code generators, and every GPU backend is disabled
  # here — verified by building 6.338.2 with all five absent). The other three
  # are load-bearing:
  #
  #   fastFloat   src/convert.cc falls back to `std::from_chars` for
  #               float/double; libc++ in Xcode 16.x does not implement the
  #               floating-point overloads, and convert.cc's own
  #               `static_assert(!is_fp, "<fast_float/fast_float.h> is
  #               required, ...")` turns that into a hard compile error.
  #               Header-only, Apache-2.0/MIT/BSL.
  #   jinja       `tools/glsl_preproc` (which runs for EVERY build, not just GPU
  #               ones — it generates src/shaders/*.c) does `import jinja2`, and
  #               libplacebo's meson.build:443-444 puts these two submodules on
  #               the generator's PYTHONPATH rather than requiring a system
  #               install. Absent, the build dies with `ModuleNotFoundError: No
  #               module named 'jinja2'` (observed: CI run 31459350681).
  #   markupsafe  jinja2's only hard runtime dependency.
  #
  # Both are BSD-3-Clause, pure Python, and are build-time tools only: nothing
  # from them reaches the shipped binary.
  fastFloat = {
    version = "2b2395f9";
    url = "https://github.com/fastfloat/fast_float/archive/2b2395f9ac836ffca6404424bcc252bff7aa80e4.tar.gz";
    sha256 = "230d20e4e4ac1f6a9df92c4d746c6ec536cdb0c085bc8635d4b88cead5dc22cb";
  };
  jinja = {
    version = "b08cd4bc";
    url = "https://github.com/pallets/jinja/archive/b08cd4bc64bb980df86ed2876978ae5735572280.tar.gz";
    sha256 = "9a20bab550a760ccb9b38a45d4fe76be92649206ee04633c646d0935a1872b0e";
  };
  markupsafe = {
    version = "c0254f0c";
    url = "https://github.com/pallets/markupsafe/archive/c0254f0cfe51720ecc9e72e8896022af29af5b44.tar.gz";
    sha256 = "1826c5d89cc1aa0b3088f538726d339e0c5cd69fbe03f7b8f9a3f880474d1120";
  };
  libpng = {
    version = "1.6.40";
    url = "https://github.com/pnggroup/libpng/archive/v1.6.40.tar.gz";
    sha256 = "62d25af25e636454b005c93cae51ddcd5383c40fa14aa3dae8f6576feb5692c2";
  };
  libpngPatch = {
    version = "1.6.40-1";
    url = "https://wrapdb.mesonbuild.com/v2/libpng_1.6.40-1/get_patch";
    sha256 = "bad558070e0a82faa5c0ae553bcd12d49021fc4b628f232a8e58c3fbd281aae1";
  };
  libvorbis = {
    version = "1.3.7";
    url = "https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz";
    sha256 = "0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab";
  };
  libvpx = {
    version = "1.13.0+1";
    url = "https://gitlab.freedesktop.org/gstreamer/meson-ports/libvpx/-/archive/90d26fac0d895969a82cd873ad36e39737104c44/libvpx-v1.13.0.tar.gz";
    sha256 = "4f872ad2709d17b848b3588231495e432c42b9263731b9121fa210a3c5a893ff";
  };
  libx264 = {
    version = "a8b68ebf";
    url = "https://code.videolan.org/videolan/x264/-/archive/a8b68ebfaa68621b5ac8907610d3335971839d52/libx264-a8b68ebfaa68621b5ac8907610d3335971839d52.tar.gz";
    sha256 = "164688b63f11a6e4f6d945057fc5c57d5eefb97973d0029fb0303744e10839ff";
  };
  libxml2 = {
    version = "2.11.5";
    url = "https://download.gnome.org/sources/libxml2/2.11/libxml2-2.11.5.tar.xz";
    sha256 = "3727b078c360ec69fa869de14bd6f75d7ee8d36987b071e6928d4720a28df3a6";
  };
  mbedtls = {
    version = "3.4.1";
    url = "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v3.4.1.tar.gz";
    sha256 = "a420fcf7103e54e775c383e3751729b8fb2dcd087f6165befd13f28315f754f5";
  };
  mpv = {
    version = "0.41.0";
    url = "https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz";
    sha256 = "ee21092a5ee427353392360929dc64645c54479aefdb5babc5cfbb5fad626209";
  };
  uchardet = {
    version = "0.0.8";
    url = "https://www.freedesktop.org/software/uchardet/releases/uchardet-0.0.8.tar.xz";
    sha256 = "e97a60cfc00a1c147a674b097bb1422abd9fa78a2d9ce3f3fdcc2e78a34ac5f0";
  };
}
