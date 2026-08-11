# https://mesonbuild.com/External-Project-module.html

project('ffmpeg', 'c', 'cpp', 'objc')

mod = import('unstable-external_project')

# build binaries
c = meson.get_compiler('c')
cpp = meson.get_compiler('cpp')
objc = meson.get_compiler('objc')
nm = find_program('nm')
ar = find_program('ar')
strip = find_program('strip')
pkg_config = find_program('pkg-config')

# build options
c_args = get_option('c_args')
cpp_args = get_option('cpp_args')
objc_args = get_option('objc_args')
c_link_args = get_option('c_link_args')

# parameters
variant = get_option('variant')
flavor = get_option('flavor')

# options
disable_all_options = [
    '--disable-autodetect',
    '--disable-all',
    '--disable-x86asm',
    '--disable-runtime-cpudetect',
    '--disable-debug',
    '--disable-stripping',
    '--disable-optimizations',
    '--disable-static',
    '--disable-shared',
    '--disable-pthreads',
    '--disable-safe-bitstream-reader',
]

common_options = [
    '--prefix=@PREFIX@',
    '--enable-small', # reduce libs size
    '--enable-optimizations',
    '--enable-shared',
    '--enable-network',
    '--enable-pthreads',
    '--enable-pic',
    '--enable-mbedtls', # tls support (mbedtls)
    '--enable-version3',
    '--enable-safe-bitstream-reader',
    '--enable-stripping',
    '--enable-avcodec',
    '--enable-avformat',
    '--enable-swresample',
    '--enable-swscale',
    '--enable-avfilter',

    # rn-media parity release: ASSERT the licence, do not merely omit the flag.
    # These two lines used to be commented-out invitations to enable GPL. The
    # outcome was the same as Android's only by omission, and a grep for
    # --disable-gpl found one fork and not the other. It also left the live
    # `encodersgpl` flavour (which really does pass --enable-gpl and link
    # libx264) one edit away from the default build. Now the audio/default
    # configure line says what it means, and `workshop verify-artifacts` can
    # assert --disable-gpl against FFmpeg's embedded configure string in the
    # shipped binary rather than against a flag list.
    '--disable-gpl',
    '--disable-nonfree',
]

audio_common_options = [
    '--enable-zlib', # rasc support
    '--enable-audiotoolbox',
]

video_common_options = [
    '--enable-neon', # improve hevc (h265) support on arm
    '--enable-libxml2', # dash support
    '--enable-videotoolbox',
    '--enable-libdav1d', # av1 support
]

# https://github.com/media-kit/libmpv-android-audio-build/blob/260666c0fef8c154971b5faf3f78da27c2bf2c40/buildscripts/flavors/default.sh
audio_default_options = [
    # decoders
    '--enable-decoder=aac*',
    '--enable-decoder=ac3',
    '--enable-decoder=alac',
    '--enable-decoder=als',
    '--enable-decoder=ape',
    '--enable-decoder=atrac*',
    '--enable-decoder=eac3',
    '--enable-decoder=flac',
    '--enable-decoder=gsm*',
    '--enable-decoder=mp1*',
    '--enable-decoder=mp2*',
    '--enable-decoder=mp3*',
    '--enable-decoder=mpc*',
    '--enable-decoder=opus',
    '--enable-decoder=ra*',
    '--enable-decoder=ralf',
    '--enable-decoder=shorten',
    '--enable-decoder=tak',
    '--enable-decoder=tta',
    '--enable-decoder=vorbis',
    '--enable-decoder=wavpack',
    '--enable-decoder=wma*',
    '--enable-decoder=pcm*',
    '--enable-decoder=dsd*',
    '--enable-decoder=dca', # required by dts

    # rn-media parity release, item 1: COVER ART.
    # Embedded album art is decoded by these. Android's audio flavour has
    # enabled them since forever and this one enabled NONE, so art that
    # rendered on Android silently failed on iOS -- a parity gap under
    # CLAUDE.md, not a size trade-off. Mirrors
    # afkcodes/libmpv-android-audio-build buildscripts/scripts/ffmpeg.sh.
    #
    # EIGHT, not nine: Android also passes --enable-decoder=ljpeg, which
    # matches NOTHING in any FFmpeg (ljpeg is an encoder only; mjpeg decodes
    # it). That dead flag is being removed from Android in this same release
    # rather than propagated here.
    '--enable-decoder=bmp',
    '--enable-decoder=gif',
    '--enable-decoder=jpeg2000',
    '--enable-decoder=jpegls',
    '--enable-decoder=mjpeg',
    '--enable-decoder=png',
    '--enable-decoder=tiff',
    '--enable-decoder=webp',

    # rn-media parity release, item 2: TrueHD / DTS-HD.
    # This flavour already had --enable-demuxer=truehd and --enable-decoder=dca
    # but neither the truehd DECODER nor the dtshd demuxer, so a .thd file
    # demuxed and then failed to decode while the same file played on Android.
    # Provenance of the Android side: upstream commit eb0af4e.
    '--enable-decoder=truehd',
    '--enable-demuxer=dtshd',

    # parsers   
    '--enable-parser=aac*',
    '--enable-parser=ac3',
    '--enable-parser=cook',
    '--enable-parser=dca',
    '--enable-parser=flac',
    '--enable-parser=gsm',
    '--enable-parser=mpegaudio',
    '--enable-parser=tak',
    '--enable-parser=vorbis',

    # demuxers
    '--enable-demuxer=aac',
    '--enable-demuxer=ac3',
    '--enable-demuxer=aiff',
    '--enable-demuxer=ape',
    '--enable-demuxer=asf',
    '--enable-demuxer=au',
    '--enable-demuxer=avi',
    '--enable-demuxer=flac',
    '--enable-demuxer=flv',
    # HLS. Note that `--enable-protocol=hls` below is NOT this: that is the
    # deprecated `hls://` protocol and is useless without the demuxer. In
    # ffmpeg 8.1.2 `hls_demuxer_select="aac_demuxer ac3_demuxer adts_header
    # ac3_parser eac3_demuxer mov_demuxer mpegts_demuxer"` (configure:3885) —
    # one entry longer than 6.0's — and configure force-enables the whole
    # `_select` chain, so these two lines add the HLS and MPEG-TS demuxers and
    # nothing else. No new external library, no GPL code: still LGPLv3 via
    # --enable-version3.
    #
    # 8.1.2 makes the point better than any comment could: FFmpeg finally
    # deleted the `hls://` protocol, so `--enable-protocol=hls` below now emits
    # `WARNING: Option --enable-protocol=hls did not match anything` and HLS
    # keeps working, because what carries it is the DEMUXER. The dead flag is
    # left in place so this diff stays about the version bump.
    # `video_default_options` has carried both since forever — only the audio
    # flavour lacked them.
    '--enable-demuxer=hls',
    '--enable-demuxer=mpegts',
    '--enable-demuxer=matroska',
    '--enable-demuxer=mov',
    '--enable-demuxer=m4v',
    '--enable-demuxer=mp3',
    '--enable-demuxer=mpc*',
    '--enable-demuxer=ogg',
    '--enable-demuxer=pcm*',
    '--enable-demuxer=rm',
    '--enable-demuxer=shorten',
    '--enable-demuxer=tak',
    '--enable-demuxer=tta',
    '--enable-demuxer=wav',
    '--enable-demuxer=wv',
    '--enable-demuxer=xwma',
    '--enable-demuxer=dsf',
    '--enable-demuxer=dts',
    '--enable-demuxer=truehd',

    # protocols
    '--enable-protocol=async',
    '--enable-protocol=cache',
    '--enable-protocol=crypto',
    '--enable-protocol=data',
    '--enable-protocol=ffrtmphttp',
    '--enable-protocol=file',
    '--enable-protocol=ftp',
    # REMOVED in this release: '--enable-protocol=hls'. FFmpeg 8.x deleted the
    # deprecated `hls://` protocol, so the flag matched nothing and configure
    # said so ("Option --enable-protocol=hls did not match anything"). HLS is
    # carried by the DEMUXER above, which is why it kept working. Dead flags are
    # being dropped on both forks in this release rather than carried forward.
    '--enable-protocol=http',
    '--enable-protocol=httpproxy',
    '--enable-protocol=https',
    '--enable-protocol=pipe',
    '--enable-protocol=rtmp',
    '--enable-protocol=rtmps',
    '--enable-protocol=rtmpt',
    '--enable-protocol=rtmpts',
    '--enable-protocol=rtp',
    '--enable-protocol=subfile',
    '--enable-protocol=tcp',
    '--enable-protocol=tls',
    # '--enable-protocol=srt', # WARNING: Option --enable-protocol=srt did not match anything

    # filters
    #
    # Same trap as the demuxers above, one layer up: `--disable-all` makes this
    # allow-list the whole world, and it held exactly two entries -- `overlay`
    # (video) and `equalizer`. `--enable-avfilter` *is* in `common_options` and
    # mpv's libavfilter bridge (filters/f_lavfi.c) *is* compiled, so
    # `af=<name>=...` resolves through avfilter_get_by_name(); it simply had
    # nothing to resolve to.
    #
    # `aresample` is the load-bearing one and is NOT optional:
    # libavfilter/avfiltergraph.c:486-492 auto-inserts `neg->conversion_filter`
    # (= "aresample" for audio) whenever two linked pads cannot agree a format,
    # and if that filter is absent graph config fails outright with
    # "'aresample' filter not present, cannot convert formats". Every filter
    # below pins a *different* sample format -- superequalizer/firequalizer
    # FLTP, anequalizer/dynaudnorm DBLP, loudnorm/crossfeed/acompressor/
    # alimiter DBL (packed), biquads S16P|S32P|FLTP|DBLP -- and loudnorm also
    # pins 192 kHz input in its non-linear mode. Its only configure dep is
    # `aresample_filter_deps="swresample"` and `--enable-swresample` is already
    # in `common_options` -- checked, not assumed.
    #
    # RE-VERIFIED against FFmpeg 8.1.2 for this engine bump by feeding the exact
    # option list below to 8.1.2's own configure: it exits 0, all 18 filters
    # land in `Enabled filters:`, and the only entry in the whole audio/default
    # list that matches nothing is the dead `--enable-protocol=hls` noted above.
    #
    # Everything else here has NO `_deps`/`_select`/`_suggest` line in FFmpeg
    # 6.0's configure (grepped `^<name>_filter_(deps|select|suggest)=` for each;
    # aresample is the only hit), so each flag costs exactly its own object:
    #   volume            af_volume.o          pre-amp / headroom before EQ boost
    #   equalizer         af_biquads.o         (already enabled; kept)
    #   bass treble       af_biquads.o         shelving; SAME object as equalizer,
    #   lowpass highpass  af_biquads.o         so these four are registration-only
    #                                          (libavfilter/Makefile:120,137,144,
    #                                          149,166)
    #   anequalizer       af_anequalizer.o     N-band parametric IIR, per-channel
    #   superequalizer    af_superequalizer.o  18-band graphic EQ
    #   firequalizer      af_firequalizer.o    linear-phase FIR EQ
    #   acompressor       af_sidechaincompress.o
    #   alimiter          af_alimiter.o        true-peak clip guard after EQ boost
    #   dynaudnorm        af_dynaudnorm.o      cheap live loudness levelling
    #   loudnorm          af_loudnorm.o + ebur128.o   EBU R128
    #   crossfeed         af_crossfeed.o       headphone crossfeed
    #   aformat anull     af_aformat.o/af_anull.o  format pinning + no-op
    #
    # superequalizer and firequalizer used to need libavcodec's RDFT; in 6.0
    # both include "libavutil/tx.h" only (af_superequalizer.c:23,
    # af_firequalizer.c:26), so they add no avcodec surface. None of these is
    # darwin-specific in any way -- no VideoToolbox/AudioToolbox path, no extra
    # external library, so `audio_common_options` is untouched.
    #
    # LICENSING -- this is the whole reason the list is not longer. FFmpeg gates
    # GPL-only components with `<name>_filter_deps="gpl"`; in 6.0 all 34 such
    # entries (configure:3636-3756) are *video* filters (eq, hqdn3d, delogo,
    # spp, pp, pullup, ...). No audio filter carries a gpl dep. So: still no
    # `--enable-gpl`/`--enable-nonfree`, `--enable-version3` -> LGPLv3.
    #
    # Mirrors afkcodes/libmpv-android-audio-build@v1.1.9-rnmedia.2 so the two
    # platforms expose the same filter set to rn-media.
    '--enable-filter=overlay',
    '--enable-filter=aresample',
    '--enable-filter=aformat',
    '--enable-filter=anull',
    '--enable-filter=volume',
    '--enable-filter=equalizer',
    '--enable-filter=bass',
    '--enable-filter=treble',
    '--enable-filter=lowpass',
    '--enable-filter=highpass',
    '--enable-filter=anequalizer',
    '--enable-filter=superequalizer',
    '--enable-filter=firequalizer',
    '--enable-filter=acompressor',
    '--enable-filter=alimiter',
    '--enable-filter=dynaudnorm',
    '--enable-filter=loudnorm',
    '--enable-filter=crossfeed',
]

# https://github.com/media-kit/libmpv-android-video-build/blob/7353af784df9bab3256acd8d90f208024d16ab96/buildscripts/flavors/default.sh
video_default_options = [
    # decoders
    '--enable-decoder=flv',
    '--enable-decoder=h263',
    '--enable-decoder=h263i',
    '--enable-decoder=h263p',
    '--enable-decoder=h264', # h264*
    '--enable-decoder=mpeg1video',
    '--enable-decoder=mpeg2video', # mpeg2*
    '--enable-decoder=mpeg4', # mpeg4*
    '--enable-decoder=vp6',
    '--enable-decoder=vp6a',
    '--enable-decoder=vp6f',
    '--enable-decoder=vp8', # vp8*
    '--enable-decoder=vp9', # vp9*
    '--enable-decoder=hevc', # hevc*
    '--enable-decoder=av1', # av1*
    '--enable-decoder=libdav1d',
    '--enable-decoder=theora',
    '--enable-decoder=msmpeg4v1', # msmpeg*
    '--enable-decoder=msmpeg4v2', # msmpeg*
    '--enable-decoder=msmpeg4v3', # msmpeg*
    '--enable-decoder=mjpeg',
    '--enable-decoder=wmv1', # wmv*
    '--enable-decoder=wmv2', # wmv*
    '--enable-decoder=wmv3', # wmv*
    '--enable-decoder=wmv3image', # wmv*

    '--enable-decoder=ssa',
    '--enable-decoder=ass',
    '--enable-decoder=dvbsub',
    '--enable-decoder=dvdsub',
    '--enable-decoder=srt',
    '--enable-decoder=stl',
    '--enable-decoder=subrip',
    '--enable-decoder=subviewer',
    '--enable-decoder=subviewer1',
    '--enable-decoder=text',
    '--enable-decoder=vplayer',
    '--enable-decoder=webvtt',
    '--enable-decoder=movtext',

    # parsers
    '--enable-parser=h263',
    '--enable-parser=h264',
    '--enable-parser=hevc',
    # '--enable-parser=mpeg4', # WARNING: Option --enable-parser=mpeg4 did not match anything
    '--enable-parser=mpeg4video',
    '--enable-parser=mpegvideo',

    # demuxers
    '--enable-demuxer=concat',
    '--enable-demuxer=data',
    '--enable-demuxer=flv',
    '--enable-demuxer=hls',
    # '--enable-demuxer=latm', # WARNING: Option --enable-demuxer=latm did not match anything
    '--enable-demuxer=live_flv',
    '--enable-demuxer=loas',
    '--enable-demuxer=m4v',
    '--enable-demuxer=mov',
    '--enable-demuxer=mpegps',
    '--enable-demuxer=mpegts',
    '--enable-demuxer=mpegvideo',
    '--enable-demuxer=hevc',
    '--enable-demuxer=rtsp',
    # '--enable-demuxer=mpeg4', # WARNING: Option --enable-demuxer=mpeg4 did not match anything
    '--enable-demuxer=mjpeg',
    '--enable-demuxer=avi',
    '--enable-demuxer=av1',
    '--enable-demuxer=matroska',
    '--enable-demuxer=dash', # --enable-libxml2 required
    '--enable-demuxer=webm_dash_manifest',

    '--enable-demuxer=ass',
    '--enable-demuxer=srt',
    '--enable-demuxer=stl',
    '--enable-demuxer=webvtt',
    '--enable-demuxer=subviewer',
    '--enable-demuxer=subviewer1',
    '--enable-demuxer=vplayer',

    # hwaccels
    '--enable-hwaccel=h263_videotoolbox',
    '--enable-hwaccel=h264_videotoolbox',
    '--enable-hwaccel=hevc_videotoolbox',
    '--enable-hwaccel=mpeg1_videotoolbox',
    '--enable-hwaccel=mpeg2_videotoolbox',
    '--enable-hwaccel=mpeg4_videotoolbox',
    '--enable-hwaccel=vp9_videotoolbox',
]

audio_full_options = [
    '--enable-decoders',
    '--enable-hwaccels',
    '--enable-parsers',
    '--enable-demuxers',
    '--enable-protocols',
    '--enable-bsfs',

    # filters
    '--enable-filter=overlay',
    '--enable-filter=equalizer',

    # TODO: `media_kit` checks the presence of the h264 decoder to determine if
    # `ffmpeg` is an audio or video variant, so we disable it for the audio
    # variant.
    # Ideally, we should only enable the audio decoders…
    '--disable-decoder=h264',
]

video_full_options = [
    '--enable-decoder=h264',
]

audio_encodersgpl_options = [
    '--enable-encoders',
    '--enable-muxers',
    '--enable-filters',
    '--enable-libvorbis',
    # TODO: If audio_encoders is going to exist as its own package, be smarter about what encoders to include
]

video_encodersgpl_options = [
    '--enable-libvpx',
    '--enable-libx264',
    '--enable-gpl'
]

# disable all option
options = disable_all_options

# common
options += common_options
options += audio_common_options
if variant == 'video'
    options += video_common_options
endif

# components
if flavor == 'default'
    options += audio_default_options
    if variant == 'video'
        options += video_default_options
    endif
elif flavor == 'full'
    options += audio_full_options
    if variant == 'video'
        options += video_full_options
    endif
elif flavor == 'encodersgpl'
    options += audio_full_options
    options += audio_encodersgpl_options
    if variant == 'video'
        options += video_full_options
        options += video_encodersgpl_options
    endif
endif

p = mod.add_project('configure',
    configure_options : options,
    cross_configure_options: [
        '--enable-cross-compile',
        '--target-os=@0@'.format(host_machine.system()),
        '--arch=@0@'.format(host_machine.cpu_family()),

        '--nm=@0@'.format(nm.path()),
        '--ar=@0@'.format(ar.path()),
        '--as=@0@'.format(''.join(c.cmd_array())),
        '--strip=@0@'.format(strip.path()),
        '--cc=@0@'.format(''.join(c.cmd_array())),
        '--cxx=@0@'.format(''.join(cpp.cmd_array())),
        '--objcc=@0@'.format(''.join(objc.cmd_array())),
        '--ld=@0@'.format(''.join(c.cmd_array())),
        '--pkg-config=@0@'.format(pkg_config.path()),

        '--host-cc=@0@'.format(''.join(c.cmd_array())),
        '--host-ld=@0@'.format(''.join(c.cmd_array())),

        '--extra-cflags=@0@'.format(' '.join(c_args)),
        '--extra-cxxflags=@0@'.format(' '.join(cpp_args)),
        '--extra-objcflags=@0@'.format(' '.join(objc_args)),
        '--extra-ldflags=@0@'.format(' '.join(c_link_args)),
    ],
    verbose: true,
)

libavfilter_dep = p.dependency('avfilter')
libswscale_dep = p.dependency('swscale')
libavcodec_dep = p.dependency('avcodec')
libavformat_dep = p.dependency('avformat')
libavutil_dep = p.dependency('avutil')
libswresample_dep = p.dependency('swresample')

meson.override_dependency('libavfilter', libavfilter_dep)
meson.override_dependency('libswscale', libswscale_dep)
meson.override_dependency('libavcodec', libavcodec_dep)
meson.override_dependency('libavformat', libavformat_dep)
meson.override_dependency('libavutil', libavutil_dep)
meson.override_dependency('libswresample', libswresample_dep)
