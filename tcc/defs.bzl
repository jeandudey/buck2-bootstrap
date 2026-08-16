# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

load("//mes:defs.bzl", "mes_cpu_select")

# The tcc Mes bootstraps with: 0.9.26 plus the patches that let MesCC compile it
# and let it compile itself. There is no released tarball of it, only the one
# its author publishes.
TCC_VERSION = "0.9.26-1149-g46a75d0c"

TCC_DIRECTORY = "tcc-{}".format(TCC_VERSION)

TCC_URLS = [
    "https://lilypond.org/janneke/tcc/{}.tar.gz".format(TCC_DIRECTORY),
]

TCC_SHA256 = "f4f6ce121ac631a234af080753fb9d645d2334d20160b37abbe75b574a1e1d19"

# tcc.h includes config.h unconditionally, and configure is what writes it. Of
# what configure puts there only the version is read anywhere in this tree, and
# it is the VERSION file rather than the name of the tarball.
CONFIG_H = [
    "/* What ./configure would generate, which the bootstrap does not run. */",
    "#define TCC_VERSION \"0.9.27\"",
    "",
]

# Where the tcc being built is told it will live. Nothing installs it there: the
# paths only become real once tcc is asked to compile something.
PREFIX = "/usr/local"

INTERPRETER = "/mes/loader"

MES_PREFIX = "mes"

# What tcc's bootstrap.sh raises the stack to, and the heap the whole of tcc in
# one translation unit needs. Mes' own defaults are not enough for either: it
# grows the arena to the maximum at every collection, so the maximum is what a
# compile costs. 35000000 is not enough and dies of a segmentation fault,
# 42000000 is; this leaves some room above that at about 1.3G of memory.
ARENA = "50000000"

STACK = "10000000"

# bootstrap.sh, for the one stage of it that MesCC rather than tcc compiles.
DEFINES = [
    "BOOTSTRAP=1",
    "inline=",
    "CONFIG_TCCDIR=\"{}/lib/tcc\"".format(PREFIX),
    "CONFIG_TCC_CRTPREFIX=\"{}/lib:{{B}}/lib:.\"".format(PREFIX),
    "CONFIG_TCC_ELFINTERP=\"{}\"".format(INTERPRETER),
    "CONFIG_TCC_LIBPATHS=\"{}/lib:{{B}}/lib:.\"".format(PREFIX),
    "CONFIG_TCC_SYSINCLUDEPATHS=\"{}/include:{}/include:{{B}}/include\"".format(MES_PREFIX, PREFIX),
    "TCC_LIBGCC=\"{}/lib/libc.a\"".format(PREFIX),
    "CONFIG_TCCBOOT=1",
    "CONFIG_TCC_STATIC=1",
    "CONFIG_USE_LIBGCC=1",
    "TCC_MES_LIBC=1",
    # Without this every generator, linker and assembler of the target ends up
    # in one translation unit; there is no x86_64-asm.c to compile on its own.
    "ONE_SOURCE=1",
]

# elf.h keeps the 64 bit ELF types behind HAVE_LONG_LONG while the structures
# that use them are not, so a 64 bit target cannot be compiled without it.
CPU_DEFINES = mes_cpu_select(
    x86 = [
        "TCC_TARGET_I386=1",
        "TCC_LIBTCC1_MES=\"libtcc1-mes.a\"",
    ],
    amd64 = [
        "TCC_TARGET_X86_64=1",
        "HAVE_LONG_LONG=1",
        "TCC_LIBTCC1_MES=\"libtcc1-mes.a\"",
    ],
    riscv64 = [
        "TCC_TARGET_RISCV64=1",
        "HAVE_LONG_LONG=1",
    ],
)

# x86_64-gen.c is the only code generator that calls abort, and abort is the one
# thing it needs that the C library tcc is built against does not carry.
EXTRA_OBJECTS = mes_cpu_select(
    x86 = [],
    amd64 = ["//mes:lib-stdlib-abort.o"],
    riscv64 = [],
)
