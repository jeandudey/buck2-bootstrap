# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

MES_VERSION = "0.27.1"

# The base address kaem.run links mes-m2 at, the same on every architecture.
BASE_ADDRESS = "0x1000000"

def mes_cpu_select(x86, amd64, riscv64):
    """Selects a per-CPU value for the architectures Mes supports.

    Mes 0.27.1 has no aarch64 port at all, see COMPATIBLE_WITH.
    """
    return select({
        "root//constraints:cpu[x86_32]": x86,
        "root//constraints:cpu[x86_64]": amd64,
        "root//constraints:cpu[riscv64]": riscv64,
    })

# There is no aarch64 Mes, so on aarch64 ask for a CPU that platform cannot
# have. That makes the targets incompatible, and buck2 skips them, rather than
# failing to configure the selects above.
COMPATIBLE_WITH = select({
    "root//constraints:cpu[aarch64]": ["root//constraints:cpu[x86_64]"],
    "DEFAULT": [],
})

def _mes_paths(fmt):
    """Per-CPU path under src, e.g. "lib/m2/{cpu}/ELF-{cpu}.hex2"."""
    return mes_cpu_select(
        x86 = ["src/" + fmt.format(cpu = "x86")],
        amd64 = ["src/" + fmt.format(cpu = "x86_64")],
        riscv64 = ["src/" + fmt.format(cpu = "riscv64")],
    )

# What the stage0 tools are told to target, "stage0_cpu" in the kaem scripts.
ARCHITECTURE = mes_cpu_select(
    x86 = "x86",
    amd64 = "amd64",
    riscv64 = "riscv64",
)

WORD_SIZE = mes_cpu_select(
    x86 = "32",
    amd64 = "64",
    riscv64 = "64",
)

# "cc_cpu" in the kaem scripts, the CPU macro the sources check for.
CPU_DEFINES = mes_cpu_select(
    x86 = ["__i386__=1"],
    amd64 = ["__x86_64__=1"],
    riscv64 = ["__riscv64__=1"],
)

# The M1 pieces mes-m2 is assembled with, its own libc rather than M2libc.
LIBC_M1 = (
    _mes_paths("lib/m2/{cpu}/{cpu}_defs.M1") +
    _mes_paths("lib/{cpu}-mes/{cpu}.M1") +
    _mes_paths("lib/linux/{cpu}-mes-m2/crt1.M1")
)

ELF_HEADER = _mes_paths("lib/m2/{cpu}/ELF-{cpu}.hex2")

# The sources kaem.run hands to M2-Planet, in its order. include/mes/config.h
# comes first but is generated, see mes_config_h.
SOURCES = (
    [
        "src/include/mes/lib-mini.h",
        "src/include/mes/lib.h",
    ] +
    _mes_paths("lib/linux/{cpu}-mes-m2/crt1.c") +
    ["src/lib/mes/__init_io.c"] +
    _mes_paths("lib/linux/{cpu}-mes-m2/_exit.c") +
    _mes_paths("lib/linux/{cpu}-mes-m2/_write.c") +
    [
        "src/lib/mes/globals.c",
        "src/lib/m2/cast.c",
        "src/lib/stdlib/exit.c",
        "src/lib/mes/write.c",
    ] +
    _mes_paths("include/linux/{cpu}/syscall.h") +
    _mes_paths("lib/linux/{cpu}-mes-m2/syscall.c") +
    [
        "src/lib/stub/__raise.c",
        "src/lib/linux/brk.c",
        "src/lib/linux/malloc.c",
        "src/lib/string/memset.c",
        "src/lib/linux/read.c",
        "src/lib/mes/fdgetc.c",
        "src/lib/stdio/getchar.c",
        "src/lib/stdio/putchar.c",
        "src/lib/stub/__buffered_read.c",
        "src/include/errno.h",
        "src/include/fcntl.h",
        "src/lib/linux/_open3.c",
        "src/lib/linux/open.c",
        "src/lib/mes/mes_open.c",
        "src/lib/string/strlen.c",
        "src/lib/mes/eputs.c",
        "src/lib/mes/fdputc.c",
        "src/lib/mes/eputc.c",
        "src/include/time.h",
        "src/include/sys/time.h",
        "src/include/m2/types.h",
        "src/include/sys/types.h",
        "src/include/sys/utsname.h",
        "src/include/mes/mes.h",
        "src/include/mes/builtins.h",
        "src/include/mes/constants.h",
        "src/include/mes/symbols.h",
        "src/lib/mes/__assert_fail.c",
        "src/lib/mes/assert_msg.c",
        "src/lib/mes/fdputc.c",
        "src/lib/string/strncmp.c",
        "src/lib/posix/getenv.c",
        "src/lib/mes/fdputs.c",
        "src/lib/mes/ntoab.c",
        "src/lib/ctype/isdigit.c",
        "src/lib/ctype/isxdigit.c",
        "src/lib/ctype/isspace.c",
        "src/lib/ctype/isnumber.c",
        "src/lib/mes/abtol.c",
        "src/lib/stdlib/atoi.c",
        "src/lib/string/memcpy.c",
        "src/lib/stdlib/free.c",
        "src/lib/stdlib/realloc.c",
        "src/lib/string/strcpy.c",
        "src/lib/mes/itoa.c",
        "src/lib/mes/ltoa.c",
        "src/lib/mes/fdungetc.c",
        "src/lib/posix/setenv.c",
        "src/lib/linux/access.c",
        "src/include/linux/m2/kernel-stat.h",
        "src/include/sys/stat.h",
        "src/lib/linux/chmod.c",
        "src/lib/linux/ioctl3.c",
        "src/include/sys/ioctl.h",
        "src/lib/m2/isatty.c",
        "src/include/signal.h",
        "src/lib/linux/fork.c",
        "src/lib/m2/execve.c",
        "src/lib/m2/execv.c",
        "src/include/sys/resource.h",
        "src/lib/linux/wait4.c",
        "src/lib/linux/waitpid.c",
        "src/lib/linux/gettimeofday.c",
        "src/lib/linux/clock_gettime.c",
        "src/lib/m2/time.c",
        "src/lib/linux/_getcwd.c",
        "src/include/limits.h",
        "src/lib/m2/getcwd.c",
        "src/lib/linux/dup.c",
        "src/lib/linux/dup2.c",
        "src/lib/string/strcmp.c",
        "src/lib/string/memcmp.c",
        "src/lib/linux/uname.c",
        "src/lib/linux/unlink.c",
        "src/src/builtins.c",
        "src/src/core.c",
        "src/src/display.c",
        "src/src/eval-apply.c",
        "src/src/gc.c",
        "src/src/hash.c",
        "src/src/lib.c",
        "src/src/m2.c",
        "src/src/math.c",
        "src/src/mes.c",
        "src/src/module.c",
        "src/src/posix.c",
        "src/src/reader.c",
        "src/src/stack.c",
        "src/src/string.c",
        "src/src/struct.c",
        "src/src/symbol.c",
        "src/src/variable.c",
        "src/src/vector.c",
    ]
)

def _config_h_impl(ctx: AnalysisContext) -> list[Provider]:
    # What configure.sh writes for a build that does not use the system libc.
    out = ctx.actions.write(ctx.label.name, [
        "#undef SYSTEM_LIBC",
        "#define MES_VERSION \"{}\"".format(ctx.attrs.version),
        "",
    ])
    return [DefaultInfo(default_output = out)]

mes_config_h = rule(
    impl = _config_h_impl,
    attrs = {
        "version": attrs.string(),
    },
)
