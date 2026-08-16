# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

# The tcc Mes bootstraps with: 0.9.26 plus the patches that let MesCC compile it
# and let it compile itself. There is no released tarball of it, only the one
# its author publishes.
TCC_VERSION = "0.9.26-1149-g46a75d0c"

TCC_URLS = [
    "https://lilypond.org/janneke/tcc/tcc-{}.tar.gz".format(TCC_VERSION),
]

TCC_SHA256 = "f4f6ce121ac631a234af080753fb9d645d2334d20160b37abbe75b574a1e1d19"
