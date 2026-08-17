# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

load("@prelude//:rules.bzl", "filegroup")

def filegroup_strip_prefix(name, srcs, prefix, **kwargs):
    """A filegroup laid out with a leading path component removed.

    Tools that are handed a directory rather than a list of files want it
    shaped the way they expect to read it, which is rarely the shape the
    sources are checked out in: an include path wants "mes/lib.h" where the
    repository has "src/include/mes/lib.h".
    """
    files = {}
    for src in srcs:
        if not src.startswith(prefix):
            fail("{} is not below {}".format(src, prefix))
        files[src[len(prefix):]] = src

    filegroup(
        name = name,
        srcs = files,
        copy = False,
        **kwargs
    )
