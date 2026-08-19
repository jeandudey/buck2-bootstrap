# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

def cpu_select(aarch64, x86, amd64, riscv64):
    """Selects a per-CPU value for the four architectures stage0 supports."""
    return select({
        "prelude//cpu/constraints:cpu[arm64]": aarch64,
        "prelude//cpu/constraints:cpu[x86_32]": x86,
        "prelude//cpu/constraints:cpu[x86_64]": amd64,
        "prelude//cpu/constraints:cpu[riscv64]": riscv64,
    })

# Architecture directory names, as spelled by stage0-posix and by M2libc.
_STAGE0_ARCHS = ("AArch64", "x86", "AMD64", "riscv64")
_M2LIBC_ARCHS = ("aarch64", "x86", "amd64", "riscv64")

def _path(fmt, archs):
    return cpu_select(
        aarch64 = fmt.format(arch = archs[0]),
        x86 = fmt.format(arch = archs[1]),
        amd64 = fmt.format(arch = archs[2]),
        riscv64 = fmt.format(arch = archs[3]),
    )

def _paths(fmt, archs):
    return cpu_select(
        aarch64 = [fmt.format(arch = archs[0])],
        x86 = [fmt.format(arch = archs[1])],
        amd64 = [fmt.format(arch = archs[2])],
        riscv64 = [fmt.format(arch = archs[3])],
    )

def stage0_path(fmt):
    """Per-CPU source path, e.g. "{arch}/hex1_{arch}.hex0"."""
    return _path("src/" + fmt, _STAGE0_ARCHS)

def stage0_paths(fmt):
    """Like stage0_path, as a single element list for "srcs" attributes."""
    return _paths("src/" + fmt, _STAGE0_ARCHS)

def _m2libc_paths(fmt):
    """Per-CPU path under src/M2libc, e.g. "{arch}/linux/unistd.c"."""
    return _paths("src/M2libc/" + fmt, _M2LIBC_ARCHS)

def _m2libc_sources(aarch64, x86, amd64, riscv64):
    """Per-CPU list of paths under src/M2libc, each a "{arch}" format string."""
    return cpu_select(
        aarch64 = ["src/M2libc/" + p.format(arch = "aarch64") for p in aarch64],
        x86 = ["src/M2libc/" + p.format(arch = "x86") for p in x86],
        amd64 = ["src/M2libc/" + p.format(arch = "amd64") for p in amd64],
        riscv64 = ["src/M2libc/" + p.format(arch = "riscv64") for p in riscv64],
    )

# The order sources are listed in decides the layout of the binary built from
# them, so every program keeps the order the stage0-posix kaem scripts use, even
# where those scripts disagree between architectures.
_UNISTD_FIRST = [
    "sys/types.h",
    "stddef.h",
    "sys/utsname.h",
    "{arch}/linux/unistd.c",
    "{arch}/linux/fcntl.c",
    "fcntl.c",
]

_FCNTL_FIRST = [
    "sys/types.h",
    "stddef.h",
    "{arch}/linux/fcntl.c",
    "fcntl.c",
    "sys/utsname.h",
    "{arch}/linux/unistd.c",
]

_UTSNAME_FIRST = [
    "sys/types.h",
    "stddef.h",
    "sys/utsname.h",
    "{arch}/linux/fcntl.c",
    "fcntl.c",
    "{arch}/linux/unistd.c",
]

M2_ARCHITECTURE = cpu_select(
    aarch64 = "aarch64",
    x86 = "x86",
    amd64 = "amd64",
    riscv64 = "riscv64",
)

WORD_SIZE = cpu_select(
    aarch64 = "64",
    x86 = "32",
    amd64 = "64",
    riscv64 = "64",
)

BASE_ADDRESS = cpu_select(
    aarch64 = "0x00600000",
    x86 = "0x8048000",
    amd64 = "0x00600000",
    riscv64 = "0x00600000",
)

# ELF headers shipped by stage0-posix itself, used until M2libc is reachable.
ELF_HEADER = cpu_select(
    aarch64 = ["src/AArch64/ELF-aarch64.hex2"],
    x86 = ["src/x86/ELF-i386.hex2"],
    amd64 = ["src/AMD64/ELF-amd64.hex2"],
    riscv64 = ["src/riscv64/ELF-riscv64.hex2"],
)

# Architecture definitions and libc that stage0-posix carries itself, used by
# the M1 sources it ships before M2libc is reachable.
STAGE0_DEFS_LIBC = cpu_select(
    aarch64 = [
        "src/AArch64/aarch64_defs.M1",
        "src/AArch64/libc-core.M1",
    ],
    x86 = [
        "src/x86/x86_defs.M1",
        "src/x86/libc-core.M1",
    ],
    amd64 = [
        "src/AMD64/amd64_defs.M1",
        "src/AMD64/libc-core.M1",
    ],
    riscv64 = [
        "src/riscv64/riscv64_defs.M1",
        "src/riscv64/libc-core.M1",
    ],
)

M2LIBC_ELF_HEADER = _m2libc_paths("{arch}/ELF-{arch}.hex2")

M2LIBC_ELF_HEADER_DEBUG = _m2libc_paths("{arch}/ELF-{arch}-debug.hex2")

M2LIBC_DEFS_LIBC = (
    _m2libc_paths("{arch}/{arch}_defs.M1") +
    _m2libc_paths("{arch}/libc-core.M1")
)

M2LIBC_DEFS_LIBC_FULL = (
    _m2libc_paths("{arch}/{arch}_defs.M1") +
    _m2libc_paths("{arch}/libc-full.M1")
)

BOOTSTRAP_C = _m2libc_paths("{arch}/linux/bootstrap.c")

M2LIBC_SYS_STAT = _m2libc_paths("{arch}/linux/sys/stat.c")

M2LIBC_SOURCES = _m2libc_sources(
    aarch64 = _UNISTD_FIRST,
    x86 = _UNISTD_FIRST,
    amd64 = _UNISTD_FIRST,
    riscv64 = _UNISTD_FIRST,
)

M2LIBC_STDIO = [
    "src/M2libc/ctype.c",
    "src/M2libc/stdlib.c",
    "src/M2libc/stdarg.h",
    "src/M2libc/stdio.h",
    "src/M2libc/stdio.c",
    "src/M2libc/bootstrappable.c",
]

HEX2_SOURCES = M2LIBC_SOURCES + M2LIBC_SYS_STAT + M2LIBC_STDIO + [
    "src/mescc-tools/hex2.h",
    "src/mescc-tools/hex2_linker.c",
    "src/mescc-tools/hex2_word.c",
    "src/mescc-tools/hex2.c",
]

M1_SOURCES = _m2libc_sources(
    aarch64 = _FCNTL_FIRST,
    x86 = _UTSNAME_FIRST,
    amd64 = _FCNTL_FIRST,
    riscv64 = _UNISTD_FIRST,
) + [
    "src/M2libc/stdarg.h",
    "src/M2libc/string.c",
    "src/M2libc/ctype.c",
    "src/M2libc/stdlib.c",
    "src/M2libc/stdio.h",
    "src/M2libc/stdio.c",
    "src/M2libc/bootstrappable.c",
    "src/mescc-tools/stringify.c",
    "src/mescc-tools/M1-macro.c",
]

KAEM_SOURCES = M2LIBC_SOURCES + [
    "src/M2libc/ctype.c",
    "src/M2libc/stdlib.c",
    "src/M2libc/string.c",
    "src/M2libc/stdarg.h",
    "src/M2libc/stdio.h",
    "src/M2libc/stdio.c",
    "src/M2libc/bootstrappable.c",
    "src/mescc-tools/Kaem/kaem.h",
    "src/mescc-tools/Kaem/variable.c",
    "src/mescc-tools/Kaem/kaem_globals.c",
    "src/mescc-tools/Kaem/kaem.c",
]

# Phases 12 to 15 are the same on every architecture and all list M2libc with
# fcntl before unistd.
_M2LIBC_SOURCES_FCNTL_FIRST = _m2libc_sources(
    aarch64 = _FCNTL_FIRST,
    x86 = _FCNTL_FIRST,
    amd64 = _FCNTL_FIRST,
    riscv64 = _FCNTL_FIRST,
)

M2_MESOPLANET_SOURCES = (
    _M2LIBC_SOURCES_FCNTL_FIRST + M2LIBC_SYS_STAT + [
        "src/M2libc/ctype.c",
        "src/M2libc/stdlib.c",
        "src/M2libc/stdarg.h",
        "src/M2libc/stdio.h",
        "src/M2libc/stdio.c",
        "src/M2libc/string.c",
        "src/M2libc/bootstrappable.c",
        "src/M2-Mesoplanet/cc.h",
        "src/M2-Mesoplanet/cc_globals.c",
        "src/M2-Mesoplanet/cc_env.c",
        "src/M2-Mesoplanet/cc_reader.c",
        "src/M2-Mesoplanet/cc_spawn.c",
        "src/M2-Mesoplanet/cc_core.c",
        "src/M2-Mesoplanet/cc_macro.c",
        "src/M2-Mesoplanet/cc.c",
    ]
)

BLOOD_ELF_SOURCES = _M2LIBC_SOURCES_FCNTL_FIRST + M2LIBC_STDIO + [
    "src/mescc-tools/stringify.c",
    "src/mescc-tools/blood-elf.c",
]

GET_MACHINE_SOURCES = M2LIBC_SOURCES + M2LIBC_STDIO + [
    "src/mescc-tools/get_machine.c",
]

M2_PLANET_SOURCES = M2LIBC_SOURCES + M2LIBC_STDIO + [
    "src/M2-Planet/cc.h",
    "src/M2-Planet/cc_globals.c",
    "src/M2-Planet/cc_reader.c",
    "src/M2-Planet/cc_strings.c",
    "src/M2-Planet/cc_types.c",
    "src/M2-Planet/cc_emit.c",
    "src/M2-Planet/cc_core.c",
    "src/M2-Planet/cc_macro.c",
    "src/M2-Planet/cc.c",
]

# The hashes stage0-posix publishes for its finished binaries, and the directory
# prefix they are listed under.
ANSWERS = _path("src/{arch}.answers", _M2LIBC_ARCHS)

ANSWERS_PREFIX = _path("{arch}/bin/", _STAGE0_ARCHS)

# The programs mescc-tools-extra ships, as target name to source name. They are
# all built the same way, by M2-Mesoplanet from a single C file.
MESCC_TOOLS_EXTRA = {
    "sha256sum_stage0": "sha256sum",
    "match_stage0": "match",
    "mkdir_stage0": "mkdir",
    "untar_stage0": "untar",
    "ungz_stage0": "ungz",
    "unbz2_stage0": "unbz2",
    "unxz_stage0": "unxz",
    "catm_stage1": "catm",
    "cp_stage0": "cp",
    "chmod_stage0": "chmod",
    "rm_stage0": "rm",
    "replace_stage0": "replace",
    "wrap_stage0": "wrap",
}

def _hex_prebuilt_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(default_output = ctx.attrs.hex),
        RunInfo(args = cmd_args(ctx.attrs.hex)),
    ]

bootstrap_hex_prebuilt = rule(
    impl = _hex_prebuilt_impl,
    attrs = {
        "hex": attrs.source(),
    },
)

def _hex_assemble_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.assembler[RunInfo], ctx.attrs.src, out.as_output()),
        category = "bootstrap_hex",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_hex_assemble = rule(
    impl = _hex_assemble_impl,
    attrs = {
        "assembler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
    },
)

def _concat_file_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.catm[RunInfo], out.as_output(), ctx.attrs.srcs),
        category = "bootstrap_catm",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_concat_file = rule(
    impl = _concat_file_impl,
    attrs = {
        "catm": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
    },
)

def _m0_assemble_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.assembler[RunInfo], ctx.attrs.src, out.as_output()),
        category = "bootstrap_m0",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_m0_assemble = rule(
    impl = _m0_assemble_impl,
    attrs = {
        "assembler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
    },
)

def _cc_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.compiler[RunInfo], ctx.attrs.src, out.as_output()),
        category = "bootstrap_cc",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_cc_compile = rule(
    impl = _cc_compile_impl,
    attrs = {
        "compiler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
    },
)

def _m2_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    cmd = cmd_args(ctx.attrs.compiler[RunInfo], "--architecture", ctx.attrs.architecture)
    for define in ctx.attrs.defines:
        cmd.add("-D", define)
    for src in ctx.attrs.srcs:
        cmd.add("-f", src)
    if ctx.attrs.bootstrap_mode:
        cmd.add("--bootstrap-mode")
    if ctx.attrs.debug:
        cmd.add("--debug")
    cmd.add("-o", out.as_output())
    ctx.actions.run(
        cmd,
        category = "bootstrap_m2",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_m2_compile = rule(
    impl = _m2_compile_impl,
    attrs = {
        "compiler": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
        "architecture": attrs.string(),
        "defines": attrs.list(attrs.string(), default = []),
        "bootstrap_mode": attrs.bool(default = False),
        "debug": attrs.bool(default = False),
    },
)

def _m1_assemble_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    cmd = cmd_args(
        ctx.attrs.assembler[RunInfo],
        "--architecture",
        ctx.attrs.architecture,
        ctx.attrs.endianness,
    )
    for src in ctx.attrs.srcs:
        cmd.add("-f", src)
    cmd.add("-o", out.as_output())
    ctx.actions.run(
        cmd,
        category = "bootstrap_m1",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_m1_assemble = rule(
    impl = _m1_assemble_impl,
    attrs = {
        "assembler": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
        "architecture": attrs.string(),
        "endianness": attrs.string(default = "--little-endian"),
    },
)

def _hex2_link_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    cmd = cmd_args(
        ctx.attrs.linker[RunInfo],
        "--architecture",
        ctx.attrs.architecture,
        ctx.attrs.endianness,
        "--base-address",
        ctx.attrs.base_address,
    )
    for src in ctx.attrs.srcs:
        cmd.add("-f", src)
    cmd.add("-o", out.as_output())
    ctx.actions.run(
        cmd,
        category = "bootstrap_hex2",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_hex2_link = rule(
    impl = _hex2_link_impl,
    attrs = {
        "linker": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
        "architecture": attrs.string(),
        "base_address": attrs.string(),
        "endianness": attrs.string(default = "--little-endian"),
    },
)

def _blood_elf_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.attrs.out or ctx.label.name)
    # blood-elf assumes 32-bit and rejects a --32 it doesn't know about.
    word_size = ["--64"] if ctx.attrs.word_size == "64" else []
    ctx.actions.run(
        cmd_args(
            ctx.attrs.blood_elf[RunInfo],
            word_size,
            ctx.attrs.endianness,
            "-f", ctx.attrs.src,
            "-o", out.as_output(),
        ),
        category = "bootstrap_blood_elf",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_blood_elf = rule(
    impl = _blood_elf_impl,
    attrs = {
        "blood_elf": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
        "word_size": attrs.enum(["32", "64"]),
        "endianness": attrs.string(default = "--little-endian"),
        "out": attrs.option(attrs.string(), default = None),
    },
)

def _subst_impl(ctx: AnalysisContext) -> list[Provider]:
    src = ctx.attrs.src
    out = None
    substitutions = ctx.attrs.substitutions.items()
    for i, (match, replacement) in enumerate(substitutions):
        last = i == len(substitutions) - 1
        out = ctx.actions.declare_output(
            ctx.label.name if last else "{}.{}".format(ctx.label.name, i),
        )
        ctx.actions.run(
            cmd_args(
                ctx.attrs.replace[RunInfo],
                "--file",
                src,
                "--match-on",
                match,
                "--replace-with",
                replacement,
                "--output",
                out.as_output(),
            ),
            category = "bootstrap_replace",
            identifier = "{}_{}".format(ctx.label.name, i),
        )
        src = out
    return [DefaultInfo(default_output = out)]

bootstrap_subst = rule(
    impl = _subst_impl,
    attrs = {
        "src": attrs.source(),
        "substitutions": attrs.dict(attrs.string(), attrs.string()),
        "replace": attrs.exec_dep(providers = [RunInfo]),
    },
)

def _m2_mesoplanet_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)

    # M2-Mesoplanet drives M2-Planet, blood-elf, M1 and hex2 itself, looking
    # them up by name in PATH, and reads M2libc out of M2LIBC_PATH.
    tools = ctx.attrs.tools[DefaultInfo].default_outputs[0]
    m2libc = ctx.attrs.m2libc[DefaultInfo].default_outputs[0]

    ctx.actions.run(
        cmd_args(
            ctx.attrs.compiler[RunInfo],
            "--operating-system",
            ctx.attrs.operating_system,
            "--architecture",
            ctx.attrs.architecture,
            "-f",
            ctx.attrs.src,
            "-o",
            out.as_output(),
            hidden = [tools, m2libc],
        ),
        env = {
            "M2LIBC_PATH": cmd_args(m2libc),
            "PATH": cmd_args(tools),
        },
        category = "bootstrap_m2_mesoplanet",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_m2_mesoplanet_compile = rule(
    impl = _m2_mesoplanet_compile_impl,
    attrs = {
        "compiler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
        "m2libc": attrs.dep(),
        "tools": attrs.exec_dep(),
        "architecture": attrs.string(),
        "operating_system": attrs.string(default = "Linux"),
    },
)

def _sha256_check_impl(ctx: AnalysisContext) -> list[Provider]:
    tools = ctx.attrs.tools[DefaultInfo].default_outputs[0]

    # Upstream lists its binaries as "<arch>/bin/<tool>", point those at ours.
    answers = ctx.actions.declare_output(ctx.label.name + ".answers")
    ctx.actions.run(
        cmd_args(
            ctx.attrs.replace[RunInfo],
            "--file",
            ctx.attrs.answers,
            "--match-on",
            ctx.attrs.prefix,
            "--replace-with",
            cmd_args(tools, format = "{}/"),
            "--output",
            answers.as_output(),
        ),
        category = "bootstrap_replace",
        identifier = ctx.label.name,
    )

    # sha256sum exits non-zero once a hash does not match. Its --output is empty
    # in check mode and only gives the action something to produce.
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(
            ctx.attrs.sha256sum[RunInfo],
            "--output",
            out.as_output(),
            "--check",
            answers,
            hidden = [tools],
        ),
        category = "bootstrap_sha256sum",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_sha256_check = rule(
    impl = _sha256_check_impl,
    attrs = {
        "answers": attrs.source(),
        "prefix": attrs.string(),
        "tools": attrs.dep(),
        "replace": attrs.exec_dep(providers = [RunInfo]),
        "sha256sum": attrs.exec_dep(providers = [RunInfo]),
    },
)

def _http_file_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.attrs.out or ctx.label.name)

    # The hash is what makes a download part of the bootstrap rather than a hole
    # in it, so there is no way to ask for one without it.
    ctx.actions.download_file(
        out,
        ctx.attrs.urls[0],
        vpnless_url = ctx.attrs.urls[1] if len(ctx.attrs.urls) > 1 else None,
        sha256 = ctx.attrs.sha256,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_http_file = rule(
    impl = _http_file_impl,
    attrs = {
        "urls": attrs.list(attrs.string()),
        "sha256": attrs.string(),
        "out": attrs.option(attrs.string(), default = None),
    },
)

def _ungz_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.attrs.out or ctx.label.name)
    ctx.actions.run(
        cmd_args(
            ctx.attrs.ungz[RunInfo],
            "--file",
            ctx.attrs.src,
            "--output",
            out.as_output(),
        ),
        category = "bootstrap_ungz",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_ungz = rule(
    impl = _ungz_impl,
    attrs = {
        "src": attrs.source(),
        "out": attrs.option(attrs.string(), default = None),
        "ungz": attrs.exec_dep(providers = [RunInfo]),
    },
)

def _untar_impl(ctx: AnalysisContext) -> list[Provider]:
    # A tarball that unpacks into a directory of its own becomes that directory,
    # so that what depends on it is not written in terms of the version.
    directory = ctx.attrs.directory
    out = ctx.actions.declare_output(directory or ctx.label.name, dir = True)
    into = cmd_args(out, ignore_artifacts = True, parent = 1 if directory else 0)

    # untar unpacks into the working directory and has no way to be pointed at
    # another one, so the directory has to be made and entered first. That is
    # what kaem is for: it is the only thing in the toolbox that can cd.
    script = ctx.actions.write(
        ctx.label.name + ".kaem",
        cmd_args(
            cmd_args(
                # kaem only takes a name for a path when it starts with a dot or
                # a slash, and everything buck2 hands it is relative.
                cmd_args(ctx.attrs.mkdir[RunInfo], format = "./{}"),
                "-p",
                into,
                delimiter = " ",
            ),
            cmd_args("cd", into, delimiter = " "),
            cmd_args(
                ctx.attrs.untar[RunInfo],
                "--file",
                ctx.attrs.src,
                delimiter = " ",
                # Everything below runs from inside that directory, and nothing
                # kaem is handed is on PATH.
                relative_to = (out, 1 if directory else 0),
            ),
            "",
        ),
        allow_args = True,
    )

    ctx.actions.run(
        cmd_args(
            ctx.attrs.kaem[RunInfo],
            "--verbose",
            "--strict",
            "--file",
            script[0],
            hidden = [
                script[1],
                ctx.attrs.mkdir[RunInfo],
                ctx.attrs.untar[RunInfo],
                ctx.attrs.src,
                out.as_output(),
            ],
        ),
        category = "bootstrap_untar",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_untar = rule(
    impl = _untar_impl,
    attrs = {
        "src": attrs.source(),
        "directory": attrs.option(attrs.string(), default = None),
        "kaem": attrs.exec_dep(providers = [RunInfo]),
        "mkdir": attrs.exec_dep(providers = [RunInfo]),
        "untar": attrs.exec_dep(providers = [RunInfo]),
    },
)

def _tree_file_impl(ctx: AnalysisContext) -> list[Provider]:
    tree = ctx.attrs.tree[DefaultInfo].default_outputs[0]
    out = ctx.actions.declare_output(ctx.attrs.out or ctx.label.name)
    ctx.actions.run(
        cmd_args(
            ctx.attrs.cp[RunInfo],
            cmd_args(tree, format = "{}/" + ctx.attrs.path),
            out.as_output(),
        ),
        category = "bootstrap_cp",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_tree_file = rule(
    impl = _tree_file_impl,
    attrs = {
        "tree": attrs.dep(),
        "path": attrs.string(),
        "out": attrs.option(attrs.string(), default = None),
        "cp": attrs.exec_dep(providers = [RunInfo]),
    },
)

def _write_file_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.write(ctx.attrs.out or ctx.label.name, ctx.attrs.content)
    return [DefaultInfo(default_output = out)]

bootstrap_write_file = rule(
    impl = _write_file_impl,
    attrs = {
        "content": attrs.list(attrs.string()),
        "out": attrs.option(attrs.string(), default = None),
    },
)

def bootstrap_hex2_image(name, catm, hex, srcs, elf_header = M2LIBC_ELF_HEADER):
    """Prepends an ELF header to srcs and assembles the result into a binary.

    Defines ":<name>.hex2" with the concatenated hex2 and ":<name>" with the
    assembled binary.
    """
    bootstrap_concat_file(
        name = name + ".hex2",
        catm = catm,
        srcs = elf_header + srcs,
    )
    bootstrap_hex_assemble(
        name = name,
        assembler = hex,
        src = ":" + name + ".hex2",
    )

def bootstrap_m2_object(
        name,
        compiler,
        srcs,
        blood_elf = None,
        bootstrap_mode = False,
        debug = False):
    """Compiles srcs with M2-Planet, optionally emitting a debug footer.

    Returns the M1 parts to hand to an assembler, in link order.
    """
    obj = name + "_no_defs_no_libc.m1"
    bootstrap_m2_compile(
        name = obj,
        compiler = compiler,
        architecture = M2_ARCHITECTURE,
        bootstrap_mode = bootstrap_mode,
        debug = debug,
        srcs = srcs,
    )
    parts = [":" + obj]

    if blood_elf != None:
        footer = name + "_footer.m1"
        bootstrap_blood_elf(
            name = footer,
            blood_elf = blood_elf,
            word_size = WORD_SIZE,
            src = ":" + obj,
        )
        parts.append(":" + footer)

    return parts

def bootstrap_m0_program(
        name,
        compiler,
        assembler,
        catm,
        hex,
        srcs,
        blood_elf = None,
        bootstrap_mode = False,
        debug = False):
    """M2-Planet program assembled by M0, for the stage before M1 exists.

    "assembler" is an M0, "hex" a hex2 assembler.
    """
    parts = bootstrap_m2_object(
        name = name,
        compiler = compiler,
        srcs = srcs,
        blood_elf = blood_elf,
        bootstrap_mode = bootstrap_mode,
        debug = debug,
    )
    bootstrap_concat_file(
        name = name + ".m1",
        catm = catm,
        srcs = M2LIBC_DEFS_LIBC + parts,
    )
    bootstrap_m0_assemble(
        name = name + "_no_elf_header.hex2",
        assembler = assembler,
        src = ":" + name + ".m1",
    )
    bootstrap_hex2_image(
        name = name,
        catm = catm,
        hex = hex,
        srcs = [":" + name + "_no_elf_header.hex2"],
        elf_header = M2LIBC_ELF_HEADER_DEBUG if debug else M2LIBC_ELF_HEADER,
    )

def bootstrap_m1_program(
        name,
        compiler,
        assembler,
        blood_elf,
        srcs,
        catm = None,
        hex = None,
        linker = None,
        visibility = None):
    """M2-Planet program assembled by M1 and turned into a binary.

    "assembler" is an M1. The binary comes either from "linker", a hex2 able to
    link, or from "hex" plus "catm" while hex2 is still assemble-only.
    """
    if (linker == None) == (hex == None):
        fail("bootstrap_m1_program needs exactly one of \"linker\" or \"hex\"")

    parts = bootstrap_m2_object(
        name = name,
        compiler = compiler,
        srcs = srcs,
        blood_elf = blood_elf,
        debug = True,
    )
    obj = name + ".hex2" if linker != None else name + "_no_elf_header.hex2"
    bootstrap_m1_assemble(
        name = obj,
        assembler = assembler,
        architecture = M2_ARCHITECTURE,
        srcs = M2LIBC_DEFS_LIBC_FULL + parts,
    )

    if linker != None:
        bootstrap_hex2_link(
            name = name,
            linker = linker,
            architecture = M2_ARCHITECTURE,
            base_address = BASE_ADDRESS,
            srcs = M2LIBC_ELF_HEADER_DEBUG + [":" + obj],
            visibility = visibility,
        )
    else:
        bootstrap_hex2_image(
            name = name,
            catm = catm,
            hex = hex,
            srcs = [":" + obj],
            elf_header = M2LIBC_ELF_HEADER_DEBUG,
        )
