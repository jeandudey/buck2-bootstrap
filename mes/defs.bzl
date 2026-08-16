# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

load(
    "//stage0:defs.bzl",
    "bootstrap_concat_file",
    "bootstrap_m1_assemble",
)

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

def _mes_path(fmt):
    """Per-CPU path under src, e.g. "lib/m2/{cpu}/ELF-{cpu}.hex2"."""
    return mes_cpu_select(
        x86 = "src/" + fmt.format(cpu = "x86"),
        amd64 = "src/" + fmt.format(cpu = "x86_64"),
        riscv64 = "src/" + fmt.format(cpu = "riscv64"),
    )

def _mes_paths(fmt):
    """Like _mes_path, as a single element list for "srcs" attributes."""
    return mes_cpu_select(
        x86 = ["src/" + fmt.format(cpu = "x86")],
        amd64 = ["src/" + fmt.format(cpu = "x86_64")],
        riscv64 = ["src/" + fmt.format(cpu = "riscv64")],
    )

MES_CPU = mes_cpu_select(
    x86 = "x86",
    amd64 = "x86_64",
    riscv64 = "riscv64",
)

# scripts/mescc.scm.in is a configure.sh template. Only the CPU and the kernel
# have to be substituted: the other variables are guarded so that an
# unsubstituted value falls back to the environment.
MESCC_SUBSTITUTIONS = mes_cpu_select(
    x86 = {
        "@mes_cpu@": "x86",
        "@mes_kernel@": "linux",
        "@VERSION@": MES_VERSION,
    },
    amd64 = {
        "@mes_cpu@": "x86_64",
        "@mes_kernel@": "linux",
        "@VERSION@": MES_VERSION,
    },
    riscv64 = {
        "@mes_cpu@": "riscv64",
        "@mes_kernel@": "linux",
        "@VERSION@": MES_VERSION,
    },
)

# The C library sources start files, per CPU.
CRT1 = _mes_path("lib/linux/{cpu}-mes-mescc/crt1.c")

# The architecture macros M1 needs ahead of anything MesCC emits.
ARCH_M1_SRC = _mes_path("lib/{cpu}-mes/{cpu}.M1")

ARCH_M1 = ["//mes:arch.M1"]

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

# What MesCC links with: the ELF header and footer of its own C library, picked
# by word size rather than by CPU. Named as targets rather than as sources, so
# that packages other than this one can link the same way.
ELF_LINK_HEADER_SRC = mes_cpu_select(
    x86 = "src/lib/linux/x86-mes/elf32-header.hex2",
    amd64 = "src/lib/linux/x86_64-mes/elf64-header.hex2",
    riscv64 = "src/lib/linux/riscv64-mes/elf64-header.hex2",
)

ELF_LINK_FOOTER_SRC = mes_cpu_select(
    x86 = "src/lib/linux/x86-mes/elf32-footer-single-main.hex2",
    amd64 = "src/lib/linux/x86_64-mes/elf64-footer-single-main.hex2",
    riscv64 = "src/lib/linux/riscv64-mes/elf64-footer-single-main.hex2",
)

ELF_LINK_HEADER = ["//mes:elf-header.hex2"]

ELF_LINK_FOOTER = ["//mes:elf-footer.hex2"]

# configure.sh copies the CPU's kernel headers into the build tree as "arch",
# next to the config.h it generates. Both are searched before the sources.
CONFIG_INCLUDE = mes_cpu_select(
    x86 = {
        "arch/kernel-stat.h": "src/include/linux/x86/kernel-stat.h",
        "arch/signal.h": "src/include/linux/x86/signal.h",
        "arch/syscall.h": "src/include/linux/x86/syscall.h",
        "mes/config.h": ":config.h",
    },
    amd64 = {
        "arch/kernel-stat.h": "src/include/linux/x86_64/kernel-stat.h",
        "arch/signal.h": "src/include/linux/x86_64/signal.h",
        "arch/syscall.h": "src/include/linux/x86_64/syscall.h",
        "mes/config.h": ":config.h",
    },
    riscv64 = {
        "arch/kernel-stat.h": "src/include/linux/riscv64/kernel-stat.h",
        "arch/signal.h": "src/include/linux/riscv64/signal.h",
        "arch/syscall.h": "src/include/linux/riscv64/syscall.h",
        "mes/config.h": ":config.h",
    },
)

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

# The Mes C library and Mes itself, as MesCC compiles them: every object once,
# keyed by the name upstream's build gives it, and the lists each archive is
# made of. Generated from build-aux/configure-lib.sh for a Linux, Mes libc,
# MesCC configuration; the lists are the same on every CPU Mes supports.
MESCC_SOURCES = {
    "lib-mes-__init_io": "src/lib/mes/__init_io.c",
    "lib-mes-eputs": "src/lib/mes/eputs.c",
    "lib-mes-oputs": "src/lib/mes/oputs.c",
    "lib-mes-globals": "src/lib/mes/globals.c",
    "lib-stdlib-exit": "src/lib/stdlib/exit.c",
    "lib-linux-mes-mescc-_exit": _mes_path("lib/linux/{cpu}-mes-mescc/_exit.c"),
    "lib-linux-mes-mescc-_write": _mes_path("lib/linux/{cpu}-mes-mescc/_write.c"),
    "lib-stdlib-puts": "src/lib/stdlib/puts.c",
    "lib-string-strlen": "src/lib/string/strlen.c",
    "lib-mes-write": "src/lib/mes/write.c",
    "lib-linux-mes-mescc-syscall-internal": _mes_path("lib/linux/{cpu}-mes-mescc/syscall-internal.c"),
    "lib-ctype-isnumber": "src/lib/ctype/isnumber.c",
    "lib-mes-abtol": "src/lib/mes/abtol.c",
    "lib-mes-cast": "src/lib/mes/cast.c",
    "lib-mes-eputc": "src/lib/mes/eputc.c",
    "lib-mes-fdgetc": "src/lib/mes/fdgetc.c",
    "lib-mes-fdputc": "src/lib/mes/fdputc.c",
    "lib-mes-fdputs": "src/lib/mes/fdputs.c",
    "lib-mes-fdungetc": "src/lib/mes/fdungetc.c",
    "lib-mes-itoa": "src/lib/mes/itoa.c",
    "lib-mes-ltoa": "src/lib/mes/ltoa.c",
    "lib-mes-ltoab": "src/lib/mes/ltoab.c",
    "lib-mes-mes_open": "src/lib/mes/mes_open.c",
    "lib-mes-ntoab": "src/lib/mes/ntoab.c",
    "lib-mes-oputc": "src/lib/mes/oputc.c",
    "lib-mes-ultoa": "src/lib/mes/ultoa.c",
    "lib-mes-utoa": "src/lib/mes/utoa.c",
    "lib-stub-__raise": "src/lib/stub/__raise.c",
    "lib-ctype-isdigit": "src/lib/ctype/isdigit.c",
    "lib-ctype-isspace": "src/lib/ctype/isspace.c",
    "lib-ctype-isxdigit": "src/lib/ctype/isxdigit.c",
    "lib-mes-assert_msg": "src/lib/mes/assert_msg.c",
    "lib-posix-write": "src/lib/posix/write.c",
    "lib-stdlib-atoi": "src/lib/stdlib/atoi.c",
    "lib-linux-lseek": "src/lib/linux/lseek.c",
    "lib-dirent-__getdirentries": "src/lib/dirent/__getdirentries.c",
    "lib-dirent-closedir": "src/lib/dirent/closedir.c",
    "lib-dirent-opendir": "src/lib/dirent/opendir.c",
    "lib-mes-__assert_fail": "src/lib/mes/__assert_fail.c",
    "lib-mes-__buffered_read": "src/lib/mes/__buffered_read.c",
    "lib-mes-__mes_debug": "src/lib/mes/__mes_debug.c",
    "lib-posix-execv": "src/lib/posix/execv.c",
    "lib-posix-getcwd": "src/lib/posix/getcwd.c",
    "lib-posix-getenv": "src/lib/posix/getenv.c",
    "lib-posix-isatty": "src/lib/posix/isatty.c",
    "lib-posix-open": "src/lib/posix/open.c",
    "lib-posix-buffered-read": "src/lib/posix/buffered-read.c",
    "lib-posix-setenv": "src/lib/posix/setenv.c",
    "lib-posix-wait": "src/lib/posix/wait.c",
    "lib-stdio-fgetc": "src/lib/stdio/fgetc.c",
    "lib-stdio-fputc": "src/lib/stdio/fputc.c",
    "lib-stdio-fputs": "src/lib/stdio/fputs.c",
    "lib-stdio-getc": "src/lib/stdio/getc.c",
    "lib-stdio-getchar": "src/lib/stdio/getchar.c",
    "lib-stdio-putc": "src/lib/stdio/putc.c",
    "lib-stdio-putchar": "src/lib/stdio/putchar.c",
    "lib-stdio-ungetc": "src/lib/stdio/ungetc.c",
    "lib-stdlib-calloc": "src/lib/stdlib/calloc.c",
    "lib-stdlib-free": "src/lib/stdlib/free.c",
    "lib-stdlib-realloc": "src/lib/stdlib/realloc.c",
    "lib-string-memchr": "src/lib/string/memchr.c",
    "lib-string-memcmp": "src/lib/string/memcmp.c",
    "lib-string-memcpy": "src/lib/string/memcpy.c",
    "lib-string-memmove": "src/lib/string/memmove.c",
    "lib-string-memset": "src/lib/string/memset.c",
    "lib-string-strcmp": "src/lib/string/strcmp.c",
    "lib-string-strcpy": "src/lib/string/strcpy.c",
    "lib-string-strncmp": "src/lib/string/strncmp.c",
    "lib-posix-raise": "src/lib/posix/raise.c",
    "lib-linux-access": "src/lib/linux/access.c",
    "lib-linux-brk": "src/lib/linux/brk.c",
    "lib-linux-chdir": "src/lib/linux/chdir.c",
    "lib-linux-chmod": "src/lib/linux/chmod.c",
    "lib-linux-clock_gettime": "src/lib/linux/clock_gettime.c",
    "lib-linux-close": "src/lib/linux/close.c",
    "lib-linux-dup": "src/lib/linux/dup.c",
    "lib-linux-dup2": "src/lib/linux/dup2.c",
    "lib-linux-execve": "src/lib/linux/execve.c",
    "lib-linux-fcntl": "src/lib/linux/fcntl.c",
    "lib-linux-fork": "src/lib/linux/fork.c",
    "lib-linux-fstat": "src/lib/linux/fstat.c",
    "lib-linux-fsync": "src/lib/linux/fsync.c",
    "lib-linux-_getcwd": "src/lib/linux/_getcwd.c",
    "lib-linux-getdents": "src/lib/linux/getdents.c",
    "lib-linux-gettimeofday": "src/lib/linux/gettimeofday.c",
    "lib-linux-ioctl3": "src/lib/linux/ioctl3.c",
    "lib-linux-link": "src/lib/linux/link.c",
    "lib-linux-lstat": "src/lib/linux/lstat.c",
    "lib-linux-_open3": "src/lib/linux/_open3.c",
    "lib-linux-malloc": "src/lib/linux/malloc.c",
    "lib-linux-mkdir": "src/lib/linux/mkdir.c",
    "lib-linux-nanosleep": "src/lib/linux/nanosleep.c",
    "lib-linux-pipe": "src/lib/linux/pipe.c",
    "lib-linux-_read": "src/lib/linux/_read.c",
    "lib-linux-readdir": "src/lib/linux/readdir.c",
    "lib-linux-rename": "src/lib/linux/rename.c",
    "lib-linux-rmdir": "src/lib/linux/rmdir.c",
    "lib-linux-stat": "src/lib/linux/stat.c",
    "lib-linux-symlink": "src/lib/linux/symlink.c",
    "lib-linux-time": "src/lib/linux/time.c",
    "lib-linux-umask": "src/lib/linux/umask.c",
    "lib-linux-uname": "src/lib/linux/uname.c",
    "lib-linux-unlink": "src/lib/linux/unlink.c",
    "lib-linux-utimensat": "src/lib/linux/utimensat.c",
    "lib-linux-wait4": "src/lib/linux/wait4.c",
    "lib-linux-waitpid": "src/lib/linux/waitpid.c",
    "lib-linux-mes-mescc-syscall": _mes_path("lib/linux/{cpu}-mes-mescc/syscall.c"),
    "lib-linux-getpid": "src/lib/linux/getpid.c",
    "lib-linux-kill": "src/lib/linux/kill.c",
    "lib-ctype-islower": "src/lib/ctype/islower.c",
    "lib-ctype-isupper": "src/lib/ctype/isupper.c",
    "lib-ctype-tolower": "src/lib/ctype/tolower.c",
    "lib-ctype-toupper": "src/lib/ctype/toupper.c",
    "lib-mes-abtod": "src/lib/mes/abtod.c",
    "lib-mes-dtoab": "src/lib/mes/dtoab.c",
    "lib-mes-search-path": "src/lib/mes/search-path.c",
    "lib-posix-execvp": "src/lib/posix/execvp.c",
    "lib-stdio-fclose": "src/lib/stdio/fclose.c",
    "lib-stdio-fdopen": "src/lib/stdio/fdopen.c",
    "lib-stdio-ferror": "src/lib/stdio/ferror.c",
    "lib-stdio-fflush": "src/lib/stdio/fflush.c",
    "lib-stdio-fopen": "src/lib/stdio/fopen.c",
    "lib-stdio-fprintf": "src/lib/stdio/fprintf.c",
    "lib-stdio-fread": "src/lib/stdio/fread.c",
    "lib-stdio-fseek": "src/lib/stdio/fseek.c",
    "lib-stdio-ftell": "src/lib/stdio/ftell.c",
    "lib-stdio-fwrite": "src/lib/stdio/fwrite.c",
    "lib-stdio-printf": "src/lib/stdio/printf.c",
    "lib-stdio-remove": "src/lib/stdio/remove.c",
    "lib-stdio-snprintf": "src/lib/stdio/snprintf.c",
    "lib-stdio-sprintf": "src/lib/stdio/sprintf.c",
    "lib-stdio-sscanf": "src/lib/stdio/sscanf.c",
    "lib-stdio-vfprintf": "src/lib/stdio/vfprintf.c",
    "lib-stdio-vprintf": "src/lib/stdio/vprintf.c",
    "lib-stdio-vsnprintf": "src/lib/stdio/vsnprintf.c",
    "lib-stdio-vsprintf": "src/lib/stdio/vsprintf.c",
    "lib-stdio-vsscanf": "src/lib/stdio/vsscanf.c",
    "lib-stdlib-qsort": "src/lib/stdlib/qsort.c",
    "lib-stdlib-strtod": "src/lib/stdlib/strtod.c",
    "lib-stdlib-strtof": "src/lib/stdlib/strtof.c",
    "lib-stdlib-strtol": "src/lib/stdlib/strtol.c",
    "lib-stdlib-strtold": "src/lib/stdlib/strtold.c",
    "lib-stdlib-strtoll": "src/lib/stdlib/strtoll.c",
    "lib-stdlib-strtoul": "src/lib/stdlib/strtoul.c",
    "lib-stdlib-strtoull": "src/lib/stdlib/strtoull.c",
    "lib-string-memmem": "src/lib/string/memmem.c",
    "lib-string-strcat": "src/lib/string/strcat.c",
    "lib-string-strchr": "src/lib/string/strchr.c",
    "lib-string-strlwr": "src/lib/string/strlwr.c",
    "lib-string-strncpy": "src/lib/string/strncpy.c",
    "lib-string-strrchr": "src/lib/string/strrchr.c",
    "lib-string-strstr": "src/lib/string/strstr.c",
    "lib-string-strupr": "src/lib/string/strupr.c",
    "lib-stub-sigaction": "src/lib/stub/sigaction.c",
    "lib-stub-ldexp": "src/lib/stub/ldexp.c",
    "lib-stub-mprotect": "src/lib/stub/mprotect.c",
    "lib-stub-localtime": "src/lib/stub/localtime.c",
    "lib-stub-putenv": "src/lib/stub/putenv.c",
    "lib-stub-realpath": "src/lib/stub/realpath.c",
    "lib-stub-sigemptyset": "src/lib/stub/sigemptyset.c",
    "lib-mes-mescc-setjmp": _mes_path("lib/{cpu}-mes-mescc/setjmp.c"),
    "src-builtins": "src/src/builtins.c",
    "src-cc": "src/src/cc.c",
    "src-core": "src/src/core.c",
    "src-display": "src/src/display.c",
    "src-eval-apply": "src/src/eval-apply.c",
    "src-gc": "src/src/gc.c",
    "src-globals": "src/src/globals.c",
    "src-hash": "src/src/hash.c",
    "src-lib": "src/src/lib.c",
    "src-math": "src/src/math.c",
    "src-mes": "src/src/mes.c",
    "src-module": "src/src/module.c",
    "src-posix": "src/src/posix.c",
    "src-reader": "src/src/reader.c",
    "src-stack": "src/src/stack.c",
    "src-string": "src/src/string.c",
    "src-struct": "src/src/struct.c",
    "src-symbol": "src/src/symbol.c",
    "src-variable": "src/src/variable.c",
    "src-vector": "src/src/vector.c",
}

LIBC_MINI_OBJECTS = [
    "lib-mes-__init_io",
    "lib-mes-eputs",
    "lib-mes-oputs",
    "lib-mes-globals",
    "lib-stdlib-exit",
    "lib-linux-mes-mescc-_exit",
    "lib-linux-mes-mescc-_write",
    "lib-stdlib-puts",
    "lib-string-strlen",
    "lib-mes-write",
]

LIBMESCC_OBJECTS = [
    "lib-mes-globals",
    "lib-linux-mes-mescc-syscall-internal",
]

LIBC_OBJECTS = [
    "lib-mes-__init_io",
    "lib-mes-eputs",
    "lib-mes-oputs",
    "lib-mes-globals",
    "lib-stdlib-exit",
    "lib-linux-mes-mescc-_exit",
    "lib-linux-mes-mescc-_write",
    "lib-stdlib-puts",
    "lib-string-strlen",
    "lib-ctype-isnumber",
    "lib-mes-abtol",
    "lib-mes-cast",
    "lib-mes-eputc",
    "lib-mes-fdgetc",
    "lib-mes-fdputc",
    "lib-mes-fdputs",
    "lib-mes-fdungetc",
    "lib-mes-itoa",
    "lib-mes-ltoa",
    "lib-mes-ltoab",
    "lib-mes-mes_open",
    "lib-mes-ntoab",
    "lib-mes-oputc",
    "lib-mes-ultoa",
    "lib-mes-utoa",
    "lib-stub-__raise",
    "lib-ctype-isdigit",
    "lib-ctype-isspace",
    "lib-ctype-isxdigit",
    "lib-mes-assert_msg",
    "lib-posix-write",
    "lib-stdlib-atoi",
    "lib-linux-lseek",
    "lib-dirent-__getdirentries",
    "lib-dirent-closedir",
    "lib-dirent-opendir",
    "lib-mes-__assert_fail",
    "lib-mes-__buffered_read",
    "lib-mes-__mes_debug",
    "lib-posix-execv",
    "lib-posix-getcwd",
    "lib-posix-getenv",
    "lib-posix-isatty",
    "lib-posix-open",
    "lib-posix-buffered-read",
    "lib-posix-setenv",
    "lib-posix-wait",
    "lib-stdio-fgetc",
    "lib-stdio-fputc",
    "lib-stdio-fputs",
    "lib-stdio-getc",
    "lib-stdio-getchar",
    "lib-stdio-putc",
    "lib-stdio-putchar",
    "lib-stdio-ungetc",
    "lib-stdlib-calloc",
    "lib-stdlib-free",
    "lib-stdlib-realloc",
    "lib-string-memchr",
    "lib-string-memcmp",
    "lib-string-memcpy",
    "lib-string-memmove",
    "lib-string-memset",
    "lib-string-strcmp",
    "lib-string-strcpy",
    "lib-string-strncmp",
    "lib-posix-raise",
    "lib-linux-access",
    "lib-linux-brk",
    "lib-linux-chdir",
    "lib-linux-chmod",
    "lib-linux-clock_gettime",
    "lib-linux-close",
    "lib-linux-dup",
    "lib-linux-dup2",
    "lib-linux-execve",
    "lib-linux-fcntl",
    "lib-linux-fork",
    "lib-linux-fstat",
    "lib-linux-fsync",
    "lib-linux-_getcwd",
    "lib-linux-getdents",
    "lib-linux-gettimeofday",
    "lib-linux-ioctl3",
    "lib-linux-link",
    "lib-linux-lstat",
    "lib-linux-_open3",
    "lib-linux-malloc",
    "lib-linux-mkdir",
    "lib-linux-nanosleep",
    "lib-linux-pipe",
    "lib-linux-_read",
    "lib-linux-readdir",
    "lib-linux-rename",
    "lib-linux-rmdir",
    "lib-linux-stat",
    "lib-linux-symlink",
    "lib-linux-time",
    "lib-linux-umask",
    "lib-linux-uname",
    "lib-linux-unlink",
    "lib-linux-utimensat",
    "lib-linux-wait4",
    "lib-linux-waitpid",
    "lib-linux-mes-mescc-syscall",
    "lib-linux-getpid",
    "lib-linux-kill",
]

# The C library tcc is built against: everything libc.a has, and the buffered
# stdio, string to number conversions and stubs that tcc needs on top of it.
LIBC_TCC_OBJECTS = LIBC_OBJECTS + [
    "lib-ctype-islower",
    "lib-ctype-isupper",
    "lib-ctype-tolower",
    "lib-ctype-toupper",
    "lib-mes-abtod",
    "lib-mes-dtoab",
    "lib-mes-search-path",
    "lib-posix-execvp",
    "lib-stdio-fclose",
    "lib-stdio-fdopen",
    "lib-stdio-ferror",
    "lib-stdio-fflush",
    "lib-stdio-fopen",
    "lib-stdio-fprintf",
    "lib-stdio-fread",
    "lib-stdio-fseek",
    "lib-stdio-ftell",
    "lib-stdio-fwrite",
    "lib-stdio-printf",
    "lib-stdio-remove",
    "lib-stdio-snprintf",
    "lib-stdio-sprintf",
    "lib-stdio-sscanf",
    "lib-stdio-vfprintf",
    "lib-stdio-vprintf",
    "lib-stdio-vsnprintf",
    "lib-stdio-vsprintf",
    "lib-stdio-vsscanf",
    "lib-stdlib-qsort",
    "lib-stdlib-strtod",
    "lib-stdlib-strtof",
    "lib-stdlib-strtol",
    "lib-stdlib-strtold",
    "lib-stdlib-strtoll",
    "lib-stdlib-strtoul",
    "lib-stdlib-strtoull",
    "lib-string-memmem",
    "lib-string-strcat",
    "lib-string-strchr",
    "lib-string-strlwr",
    "lib-string-strncpy",
    "lib-string-strrchr",
    "lib-string-strstr",
    "lib-string-strupr",
    "lib-stub-sigaction",
    "lib-stub-ldexp",
    "lib-stub-mprotect",
    "lib-stub-localtime",
    "lib-stub-putenv",
    "lib-stub-realpath",
    "lib-stub-sigemptyset",
    "lib-mes-mescc-setjmp",
]

# The C library the bootstrap goes on with once tcc can compile it: everything
# libc+tcc.a has, and the maths, string and stub functions the programs after
# tcc reach for. It is one translation unit rather than one object per source,
# the way upstream's bootstrap.sh and live-bootstrap both build it, and the
# arch specific parts are the ones written for a compiler with inline assembly
# rather than the ones MesCC needs. Generated from build-aux/configure-lib.sh.
LIBC_GNU_SOURCES = (
    [
        "src/lib/mes/__init_io.c",
        "src/lib/mes/eputs.c",
        "src/lib/mes/oputs.c",
        "src/lib/mes/globals.c",
        "src/lib/stdlib/exit.c",
    ] +
    _mes_paths("lib/linux/{cpu}-mes-gcc/_exit.c") +
    _mes_paths("lib/linux/{cpu}-mes-gcc/_write.c") +
    [
        "src/lib/stdlib/puts.c",
        "src/lib/string/strlen.c",
        "src/lib/ctype/isnumber.c",
        "src/lib/mes/abtol.c",
        "src/lib/mes/cast.c",
        "src/lib/mes/eputc.c",
        "src/lib/mes/fdgetc.c",
        "src/lib/mes/fdputc.c",
        "src/lib/mes/fdputs.c",
        "src/lib/mes/fdungetc.c",
        "src/lib/mes/itoa.c",
        "src/lib/mes/ltoa.c",
        "src/lib/mes/ltoab.c",
        "src/lib/mes/mes_open.c",
        "src/lib/mes/ntoab.c",
        "src/lib/mes/oputc.c",
        "src/lib/mes/ultoa.c",
        "src/lib/mes/utoa.c",
        "src/lib/stub/__raise.c",
        "src/lib/ctype/isdigit.c",
        "src/lib/ctype/isspace.c",
        "src/lib/ctype/isxdigit.c",
        "src/lib/mes/assert_msg.c",
        "src/lib/posix/write.c",
        "src/lib/stdlib/atoi.c",
        "src/lib/linux/lseek.c",
        "src/lib/dirent/__getdirentries.c",
        "src/lib/dirent/closedir.c",
        "src/lib/dirent/opendir.c",
        "src/lib/mes/__assert_fail.c",
        "src/lib/mes/__buffered_read.c",
        "src/lib/mes/__mes_debug.c",
        "src/lib/posix/execv.c",
        "src/lib/posix/getcwd.c",
        "src/lib/posix/getenv.c",
        "src/lib/posix/isatty.c",
        "src/lib/posix/open.c",
        "src/lib/posix/buffered-read.c",
        "src/lib/posix/setenv.c",
        "src/lib/posix/wait.c",
        "src/lib/stdio/fgetc.c",
        "src/lib/stdio/fputc.c",
        "src/lib/stdio/fputs.c",
        "src/lib/stdio/getc.c",
        "src/lib/stdio/getchar.c",
        "src/lib/stdio/putc.c",
        "src/lib/stdio/putchar.c",
        "src/lib/stdio/ungetc.c",
        "src/lib/stdlib/calloc.c",
        "src/lib/stdlib/free.c",
        "src/lib/stdlib/realloc.c",
        "src/lib/string/memchr.c",
        "src/lib/string/memcmp.c",
        "src/lib/string/memcpy.c",
        "src/lib/string/memmove.c",
        "src/lib/string/memset.c",
        "src/lib/string/strcmp.c",
        "src/lib/string/strcpy.c",
        "src/lib/string/strncmp.c",
        "src/lib/posix/raise.c",
        "src/lib/linux/access.c",
        "src/lib/linux/brk.c",
        "src/lib/linux/chdir.c",
        "src/lib/linux/chmod.c",
        "src/lib/linux/clock_gettime.c",
        "src/lib/linux/close.c",
        "src/lib/linux/dup.c",
        "src/lib/linux/dup2.c",
        "src/lib/linux/execve.c",
        "src/lib/linux/fcntl.c",
        "src/lib/linux/fork.c",
        "src/lib/linux/fstat.c",
        "src/lib/linux/fsync.c",
        "src/lib/linux/_getcwd.c",
        "src/lib/linux/getdents.c",
        "src/lib/linux/gettimeofday.c",
        "src/lib/linux/ioctl3.c",
        "src/lib/linux/link.c",
        "src/lib/linux/lstat.c",
        "src/lib/linux/_open3.c",
        "src/lib/linux/malloc.c",
        "src/lib/linux/mkdir.c",
        "src/lib/linux/nanosleep.c",
        "src/lib/linux/pipe.c",
        "src/lib/linux/_read.c",
        "src/lib/linux/readdir.c",
        "src/lib/linux/rename.c",
        "src/lib/linux/rmdir.c",
        "src/lib/linux/stat.c",
        "src/lib/linux/symlink.c",
        "src/lib/linux/time.c",
        "src/lib/linux/umask.c",
        "src/lib/linux/uname.c",
        "src/lib/linux/unlink.c",
        "src/lib/linux/utimensat.c",
        "src/lib/linux/wait4.c",
        "src/lib/linux/waitpid.c",
    ] +
    _mes_paths("lib/linux/{cpu}-mes-gcc/syscall.c") +
    [
        "src/lib/linux/getpid.c",
        "src/lib/linux/kill.c",
        "src/lib/ctype/islower.c",
        "src/lib/ctype/isupper.c",
        "src/lib/ctype/tolower.c",
        "src/lib/ctype/toupper.c",
        "src/lib/mes/abtod.c",
        "src/lib/mes/dtoab.c",
        "src/lib/mes/search-path.c",
        "src/lib/posix/execvp.c",
        "src/lib/stdio/fclose.c",
        "src/lib/stdio/fdopen.c",
        "src/lib/stdio/ferror.c",
        "src/lib/stdio/fflush.c",
        "src/lib/stdio/fopen.c",
        "src/lib/stdio/fprintf.c",
        "src/lib/stdio/fread.c",
        "src/lib/stdio/fseek.c",
        "src/lib/stdio/ftell.c",
        "src/lib/stdio/fwrite.c",
        "src/lib/stdio/printf.c",
        "src/lib/stdio/remove.c",
        "src/lib/stdio/snprintf.c",
        "src/lib/stdio/sprintf.c",
        "src/lib/stdio/sscanf.c",
        "src/lib/stdio/vfprintf.c",
        "src/lib/stdio/vprintf.c",
        "src/lib/stdio/vsnprintf.c",
        "src/lib/stdio/vsprintf.c",
        "src/lib/stdio/vsscanf.c",
        "src/lib/stdlib/qsort.c",
        "src/lib/stdlib/strtod.c",
        "src/lib/stdlib/strtof.c",
        "src/lib/stdlib/strtol.c",
        "src/lib/stdlib/strtold.c",
        "src/lib/stdlib/strtoll.c",
        "src/lib/stdlib/strtoul.c",
        "src/lib/stdlib/strtoull.c",
        "src/lib/string/memmem.c",
        "src/lib/string/strcat.c",
        "src/lib/string/strchr.c",
        "src/lib/string/strlwr.c",
        "src/lib/string/strncpy.c",
        "src/lib/string/strrchr.c",
        "src/lib/string/strstr.c",
        "src/lib/string/strupr.c",
        "src/lib/stub/sigaction.c",
        "src/lib/stub/ldexp.c",
        "src/lib/stub/mprotect.c",
        "src/lib/stub/localtime.c",
        "src/lib/stub/putenv.c",
        "src/lib/stub/realpath.c",
        "src/lib/stub/sigemptyset.c",
    ] +
    _mes_paths("lib/{cpu}-mes-gcc/setjmp.c") +
    [
        "src/lib/ctype/isalnum.c",
        "src/lib/ctype/isalpha.c",
        "src/lib/ctype/isascii.c",
        "src/lib/ctype/iscntrl.c",
        "src/lib/ctype/isgraph.c",
        "src/lib/ctype/isprint.c",
        "src/lib/ctype/ispunct.c",
        "src/lib/math/ceil.c",
        "src/lib/math/fabs.c",
        "src/lib/math/floor.c",
        "src/lib/mes/fdgets.c",
        "src/lib/posix/alarm.c",
        "src/lib/posix/execl.c",
        "src/lib/posix/execlp.c",
        "src/lib/posix/mktemp.c",
        "src/lib/posix/pathconf.c",
        "src/lib/posix/sbrk.c",
        "src/lib/posix/sleep.c",
        "src/lib/posix/unsetenv.c",
        "src/lib/stdio/clearerr.c",
        "src/lib/stdio/feof.c",
        "src/lib/stdio/fgets.c",
        "src/lib/stdio/fileno.c",
        "src/lib/stdio/freopen.c",
        "src/lib/stdio/fscanf.c",
        "src/lib/stdio/perror.c",
        "src/lib/stdio/vfscanf.c",
        "src/lib/stdlib/__exit.c",
        "src/lib/stdlib/abort.c",
        "src/lib/stdlib/abs.c",
        "src/lib/stdlib/alloca.c",
        "src/lib/stdlib/atexit.c",
        "src/lib/stdlib/atof.c",
        "src/lib/stdlib/atol.c",
        "src/lib/stdlib/mbstowcs.c",
        "src/lib/string/bcmp.c",
        "src/lib/string/bcopy.c",
        "src/lib/string/bzero.c",
        "src/lib/string/index.c",
        "src/lib/string/rindex.c",
        "src/lib/string/strcspn.c",
        "src/lib/string/strdup.c",
        "src/lib/string/strerror.c",
        "src/lib/string/strncat.c",
        "src/lib/string/strpbrk.c",
        "src/lib/string/strspn.c",
        "src/lib/stub/__cleanup.c",
        "src/lib/stub/atan2.c",
        "src/lib/stub/bsearch.c",
        "src/lib/stub/chown.c",
        "src/lib/stub/cos.c",
        "src/lib/stub/ctime.c",
        "src/lib/stub/exp.c",
        "src/lib/stub/fpurge.c",
        "src/lib/stub/freadahead.c",
        "src/lib/stub/frexp.c",
        "src/lib/stub/getgrgid.c",
        "src/lib/stub/getgrnam.c",
        "src/lib/stub/getlogin.c",
        "src/lib/stub/getpgid.c",
        "src/lib/stub/getpgrp.c",
        "src/lib/stub/getpwnam.c",
        "src/lib/stub/getpwuid.c",
        "src/lib/stub/gmtime.c",
        "src/lib/stub/log.c",
        "src/lib/stub/mktime.c",
        "src/lib/stub/modf.c",
        "src/lib/stub/pclose.c",
        "src/lib/stub/popen.c",
        "src/lib/stub/pow.c",
        "src/lib/stub/rand.c",
        "src/lib/stub/rewind.c",
        "src/lib/stub/setbuf.c",
        "src/lib/stub/setgrent.c",
        "src/lib/stub/setlocale.c",
        "src/lib/stub/setvbuf.c",
        "src/lib/stub/sigaddset.c",
        "src/lib/stub/sigblock.c",
        "src/lib/stub/sigdelset.c",
        "src/lib/stub/sigsetmask.c",
        "src/lib/stub/sin.c",
        "src/lib/stub/sqrt.c",
        "src/lib/stub/strftime.c",
        "src/lib/stub/sys_siglist.c",
        "src/lib/stub/system.c",
        "src/lib/stub/times.c",
        "src/lib/stub/ttyname.c",
        "src/lib/stub/utime.c",
        "src/lib/linux/getegid.c",
        "src/lib/linux/geteuid.c",
        "src/lib/linux/getgid.c",
        "src/lib/linux/getppid.c",
        "src/lib/linux/getrusage.c",
        "src/lib/linux/getuid.c",
        "src/lib/linux/ioctl.c",
        "src/lib/linux/mknod.c",
        "src/lib/linux/readlink.c",
        "src/lib/linux/setgid.c",
        "src/lib/linux/settimer.c",
        "src/lib/linux/setuid.c",
        "src/lib/linux/signal.c",
        "src/lib/linux/sigprogmask.c",
    ]
)

# What a program tcc links starts and ends with. MesCC only ever needed crt1,
# so these come from the gcc flavour of the same directory, which is the one
# that has all three.
CRT1_C = _mes_path("lib/linux/{cpu}-mes-gcc/crt1.c")

CRTI_C = _mes_path("lib/linux/{cpu}-mes-gcc/crti.c")

CRTN_C = _mes_path("lib/linux/{cpu}-mes-gcc/crtn.c")

MES_OBJECTS = [
    "src-builtins",
    "src-cc",
    "src-core",
    "src-display",
    "src-eval-apply",
    "src-gc",
    "src-globals",
    "src-hash",
    "src-lib",
    "src-math",
    "src-mes",
    "src-module",
    "src-posix",
    "src-reader",
    "src-stack",
    "src-string",
    "src-struct",
    "src-symbol",
    "src-variable",
    "src-vector",
]

# cmd: runs mescc under Mes, arguments still to follow.
# env: what Mes and mescc need in the environment.
# includes: the -I flags for the Mes C library headers.
MesccInfo = provider(fields = ["cmd", "env", "includes"])

def _mescc_impl(ctx: AnalysisContext) -> list[Provider]:
    prefix = ctx.attrs.mes_prefix[DefaultInfo].default_outputs[0]
    modules = ctx.attrs.modules[DefaultInfo].default_outputs[0]
    nyacc = ctx.attrs.nyacc[DefaultInfo].default_outputs[0]
    includes = [dep[DefaultInfo].default_outputs[0] for dep in ctx.attrs.includes]

    # MesCC is Scheme: Mes reads scripts/mescc.scm, and "--" separates Mes' own
    # arguments from the ones mescc parses.
    cmd = cmd_args(
        ctx.attrs.mes[RunInfo],
        "--no-auto-compile",
        "-e",
        "main",
        ctx.attrs.script,
        "--",
        hidden = [prefix, modules, nyacc] + includes,
    )
    env = {
        # Mes reads boot-5.scm from below MES_PREFIX.
        "MES_PREFIX": cmd_args(prefix),
        "GUILE_LOAD_PATH": cmd_args(
            [cmd_args(prefix, format = "{}/mes/module"), modules, nyacc],
            delimiter = ":",
        ),
        "MES_ARENA": ctx.attrs.arena,
        "MES_MAX_ARENA": ctx.attrs.arena,
        "MES_STACK": ctx.attrs.stack,
    }
    include_flags = cmd_args()
    for include in includes:
        include_flags.add("-I", include)

    return [
        DefaultInfo(default_output = ctx.attrs.script),
        MesccInfo(cmd = cmd, env = env, includes = include_flags),
    ]

mescc = rule(
    impl = _mescc_impl,
    attrs = {
        "mes": attrs.exec_dep(providers = [RunInfo]),
        "script": attrs.source(),
        "mes_prefix": attrs.dep(),
        "modules": attrs.dep(),
        "nyacc": attrs.dep(),
        "includes": attrs.list(attrs.dep()),
        "arena": attrs.string(default = "20000000"),
        "stack": attrs.string(default = "6000000"),
    },
)

def _mescc_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    mescc = ctx.attrs.mescc[MesccInfo]
    out = ctx.actions.declare_output(ctx.label.name)

    # Stop at the assembly MesCC emits: M1 and hex2 are targets of their own
    # rather than subprocesses of the compiler.
    cmd = cmd_args(
        mescc.cmd,
        "-S",
        "-o",
        out.as_output(),
        # MesCC searches the directory of the source too, for the few files
        # that include a sibling.
        hidden = ctx.attrs.headers,
    )
    for define in ctx.attrs.defines:
        cmd.add("-D", define)

    # Ahead of the Mes C library, the way upstream builds anything that carries
    # headers of its own.
    for include in ctx.attrs.includes:
        cmd.add("-I", include[DefaultInfo].default_outputs[0])
    cmd.add(mescc.includes, ctx.attrs.src)

    # Mes neither grows its heap past MES_MAX_ARENA nor checks its stack: it
    # dies of a segmentation fault on a source large enough, so a source that
    # needs more room than mescc was given says how much.
    env = mescc.env
    if ctx.attrs.arena or ctx.attrs.stack:
        env = dict(env)
        if ctx.attrs.arena:
            env["MES_ARENA"] = ctx.attrs.arena
            env["MES_MAX_ARENA"] = ctx.attrs.arena
        if ctx.attrs.stack:
            env["MES_STACK"] = ctx.attrs.stack

    ctx.actions.run(
        cmd,
        env = env,
        category = "mescc",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

mescc_compile = rule(
    impl = _mescc_compile_impl,
    attrs = {
        # Which CPU MesCC compiles for is baked into the script rather than
        # passed to it, so mescc belongs to the target rather than to the
        # machine it runs on. Mes itself is what has to run here, and the mescc
        # rule asks for that one as an exec_dep.
        "mescc": attrs.dep(providers = [MesccInfo]),
        "src": attrs.source(),
        "headers": attrs.list(attrs.source(), default = []),
        "includes": attrs.list(attrs.dep(), default = []),
        "defines": attrs.list(attrs.string(), default = ["HAVE_CONFIG_H=1"]),
        "arena": attrs.option(attrs.string(), default = None),
        "stack": attrs.option(attrs.string(), default = None),
    },
)

def mescc_object(
        name,
        mescc,
        assembler,
        src,
        headers = [],
        includes = [],
        defines = None,
        arena = None,
        stack = None,
        visibility = None):
    """Compiles one C file the way MesCC does, in two visible steps.

    Defines ":<name>.s" with the assembly and ":<name>.o" with what M1 makes of
    it. MesCC would run M1 itself; here it stops at the assembly.
    """
    mescc_compile(
        name = name + ".s",
        mescc = mescc,
        src = src,
        headers = headers,
        includes = includes,
        defines = defines,
        arena = arena,
        stack = stack,
        target_compatible_with = COMPATIBLE_WITH,
    )
    bootstrap_m1_assemble(
        name = name + ".o",
        assembler = assembler,
        architecture = ARCHITECTURE,
        srcs = ARCH_M1 + [":" + name + ".s"],
        target_compatible_with = COMPATIBLE_WITH,
        visibility = visibility,
    )

def mescc_objects(mescc, assembler, sources, headers = []):
    """Compiles a set of objects, one target per source."""
    for name, src in sources.items():
        mescc_object(
            name = name,
            mescc = mescc,
            assembler = assembler,
            src = src,
            headers = headers,
        )

def mescc_archive(name, catm, objects, visibility = None):
    """An archive as mesar makes one: the objects concatenated, no index.

    Defines ":<name>.a" for the linker and ":<name>.s" for blood-elf.
    """
    bootstrap_concat_file(
        name = name + ".a",
        catm = catm,
        srcs = [":" + o + ".o" for o in objects],
        target_compatible_with = COMPATIBLE_WITH,
        visibility = visibility,
    )
    bootstrap_concat_file(
        name = name + ".s",
        catm = catm,
        srcs = [":" + o + ".s" for o in objects],
        target_compatible_with = COMPATIBLE_WITH,
        visibility = visibility,
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
