# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

load("//mes:defs.bzl", "COMPATIBLE_WITH", "mes_cpu_select")

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

# What the Mes C library is compiled with once tcc rather than MesCC compiles
# it. HAVE_CONFIG_H is all configure.sh leaves behind; the headers come from
# the include trees, so nothing here says where anything lives.
LIBC_DEFINES = ["HAVE_CONFIG_H=1"]

# libtcc1 is the arithmetic tcc's code generators call rather than emit, so it
# is built for what the target has whatever the C library was built for.
LIBTCC1_DEFINES = LIBC_DEFINES + [
    "HAVE_FLOAT=1",
    "HAVE_LONG_LONG=1",
]

# What has to be written differently for MesCC to compile it: the value stack
# swap in x86_64-gen.c's gfunc_call, whose "SValue tmp = vtop[0];" MesCC turns
# into a copy of the address rather than of the struct. The assignment on its
# own is compiled correctly, so declaring first is the whole of the fix.
MESCC_FIXES = {
    "SValue tmp = vtop[0];": "SValue tmp; tmp = vtop[0];",
}

# tcc's own bug rather than MesCC's, and only reachable on x86_64. Every call to
# a global there is relocated through a PLT stub whose jump goes to the GOT, and
# the stubs are pointed at the GOT by relocate_plt, which runs only when the
# output has a dynamic section. A static executable therefore comes out with the
# right addresses in its GOT and stubs that jump into the middle of the PLT. The
# same rewrite the visibility test already does resolves the call straight to
# the symbol, which is what the i386 code generator does for every static link
# and why nothing is wrong there.
LINKER_FIXES = {
    "(ELFW(ST_VISIBILITY)(sym->st_other) != STV_DEFAULT ||": "(s1->static_link || ELFW(ST_VISIBILITY)(sym->st_other) != STV_DEFAULT ||",
}

# Neither of the two is wanted anywhere but on amd64, and x86 is the CPU whose
# bootstrap upstream has actually run, so it compiles the tarball as it came.
REWRITTEN_SOURCES = mes_cpu_select(
    x86 = {},
    amd64 = {
        "tccelf.c": "//tcc:tccelf.c",
        "x86_64-gen.c": "//tcc:x86_64-gen.c",
    },
    riscv64 = {},
)

# The Mes headers, and the ones configure.sh generates, in the order upstream
# searches them.
INCLUDES = [
    "//mes:config_include",
    "//mes:include",
]

def _tcc_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)

    # tcc's built in include paths name a prefix that exists only once it is
    # installed. Nothing is there to be found, and -nostdinc says so rather
    # than leaving it to whatever the machine happens to have.
    cmd = cmd_args(
        ctx.attrs.tcc[RunInfo],
        "-c",
        "-nostdinc",
        "-o",
        out.as_output(),
    )
    for define in ctx.attrs.defines:
        cmd.add("-D", define)
    for include in ctx.attrs.includes:
        cmd.add("-I", include[DefaultInfo].default_outputs[0])
    cmd.add(ctx.attrs.src)

    ctx.actions.run(cmd, category = "tcc", identifier = ctx.label.name)
    return [DefaultInfo(default_output = out)]

# Which CPU tcc compiles for is built into the binary rather than chosen on the
# command line, so the compiler belongs to the target and not to the machine it
# runs on: hence a dep rather than an exec_dep. A build whose target is not the
# machine's own architecture needs something able to run it.
_TCC_ATTR = attrs.dep(providers = [RunInfo])

tcc_compile = rule(
    impl = _tcc_compile_impl,
    attrs = {
        "tcc": _TCC_ATTR,
        "src": attrs.source(),
        "includes": attrs.list(attrs.dep(), default = []),
        "defines": attrs.list(attrs.string(), default = []),
    },
)

def _tcc_archive_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)

    # An ar archive with a symbol index, rather than the objects catted
    # together that mesar calls one. The member headers in it are not what
    # ar(1) expects, because MesCC compiles the static ArHdr tcc writes them
    # from into pointers to its string literals instead of the strings; tcc
    # reads its own archives by size and does not mind. Nothing else has to
    # read them until a real ar exists.
    ctx.actions.run(
        cmd_args(
            ctx.attrs.tcc[RunInfo],
            "-ar",
            "cr",
            out.as_output(),
            ctx.attrs.objects,
        ),
        category = "tcc_ar",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

tcc_archive = rule(
    impl = _tcc_archive_impl,
    attrs = {
        "tcc": _TCC_ATTR,
        "objects": attrs.list(attrs.source()),
    },
)

def tcc_object(name, tcc, src, defines = LIBC_DEFINES, includes = INCLUDES, visibility = None):
    """Compiles one C file with tcc, for the CPU that tcc was built for."""
    tcc_compile(
        name = name,
        tcc = tcc,
        src = src,
        defines = defines,
        includes = includes,
        target_compatible_with = COMPATIBLE_WITH,
        visibility = visibility,
    )

def tcc_library(name, tcc, src, defines = LIBC_DEFINES, includes = INCLUDES, visibility = None):
    """One source, one object, one archive: how the Mes libraries are built."""
    tcc_object(
        name = name + ".o",
        tcc = tcc,
        src = src,
        defines = defines,
        includes = includes,
    )
    tcc_archive(
        name = name + ".a",
        tcc = tcc,
        objects = [":" + name + ".o"],
        target_compatible_with = COMPATIBLE_WITH,
        visibility = visibility,
    )
