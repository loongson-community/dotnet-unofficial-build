#!/usr/bin/env python3

from collections.abc import Mapping
import pathlib
import re
from string import Template
import sys
from typing import Iterator, NamedTuple
from urllib.parse import urljoin, quote


TAG_REF_PREFIX = "refs/tags/"
RE_PORTABLE_RID = re.compile(
    r"[-.]((?:android|ios|iossimulator|linux|linux-bionic|linux-musl|osx|win)-[0-9a-z]+)\.tar(?:\.gz|\.bz2|\.xz|\.zst)?$"
)

def usage(argv0: str) -> int:
    print(
        f"usage: {argv0} <owner/repo> <{TAG_REF_PREFIX}/RELEASE-TAG-NAME> <path/to/out/dir>",
        file=sys.stderr,
    )
    return 1


def extract_rid(name: str) -> str:
    if m := RE_PORTABLE_RID.search(name):
        return m.group(1)
    raise ValueError(f"not name of an archive with RID: {name}")


class URLMaker:
    def __init__(self, owner_repo: str, release_name: str) -> None:
        release_name = quote(release_name)
        self._base = f"https://github.com/{owner_repo}/releases/download/{release_name}/"

    def make_download_url(self, asset_name: str) -> str:
        return urljoin(self._base, quote(asset_name))


class MiscFile(NamedTuple):
    name: str
    desc: str


class TemplateCtx(Mapping[str, str]):
    def __init__(self, um: URLMaker) -> None:
        self._um = um
        self._known_rids: dict[str, None] = {}
        self._sdk_archives_by_rid: dict[str, str] = {}
        self._symbols_all_archives_by_rid: dict[str, str] = {}
        self._symbols_sdk_archives_by_rid: dict[str, str] = {}
        self._misc_files: list[MiscFile] = []

    def _note_rid(self, rid: str) -> None:
        self._known_rids[rid] = None

    def add_sdk_archive(self, name: str) -> None:
        # name is like "dotnet-sdk-9.0.101-linux-x64.tar.gz"
        rid = extract_rid(name)
        self._note_rid(rid)
        self._sdk_archives_by_rid[rid] = name

    def add_symbol_archive(self, name: str) -> None:
        rid = extract_rid(name)
        self._note_rid(rid)
        if name.startswith("dotnet-symbols-all-"):
            self._symbols_all_archives_by_rid[rid] = name
        elif name.startswith("dotnet-symbols-sdk-"):
            self._symbols_sdk_archives_by_rid[rid] = name
        else:
            raise ValueError(f"unexpected symbol archive kind: {name}")

    def _add_misc_file(self, f: MiscFile) -> None:
        self._misc_files.append(f)

    def add_sb_artifacts_archive(self, name: str) -> None:
        rid = extract_rid(name)
        self._note_rid(rid)
        return self._add_misc_file(
            MiscFile(name, f"源码构建用产物包 / Source-build artifacts - `{rid}`"),
        )

    def add_sdk_feed_archive(self, name: str) -> None:
        if name.startswith("sdk-feed-stage1"):
            return self._add_misc_file(
                MiscFile(name, "更新源用物料 / SDK feed material - `linux-x64`"),
            )
        elif name.startswith("sdk-feed-stage2"):
            rid = extract_rid(name)
            self._note_rid(rid)
            return self._add_misc_file(
                MiscFile(name, f"更新源用物料 / SDK feed material - `{rid}`"),
            )
        else:
            raise ValueError(f"unexpected sdk feed archive name: {name}")

    def make_row(self, filename: str, desc: str) -> str:
        url = self._um.make_download_url(filename)
        sha256 = self._um.make_download_url(filename + ".sha256")
        sha512 = self._um.make_download_url(filename + ".sha512")
        return f"| [{desc}]({url}) | [SHA256]({sha256}), [SHA512]({sha512}) |\n"

    def rid_assets_rows(self, rid: str) -> list[str]:
        result: list[str] = []
        if f := self._sdk_archives_by_rid.get(rid, None):
            result.append(self.make_row(f, ".NET SDK"))
        if f := self._symbols_all_archives_by_rid.get(rid, None):
            result.append(self.make_row(f, "调试符号 (所有) / Debug symbols (all)"))
        if f := self._symbols_sdk_archives_by_rid.get(rid, None):
            result.append(self.make_row(f, "调试符号 (SDK) / Debug symbols (SDK)"))
        return result

    def misc_files_rows(self) -> list[str]:
        return [self.make_row(mf.name, mf.desc) for mf in sorted(self._misc_files)]

    def __iter__(self) -> Iterator[str]:
        # "rid_*" and "misc"
        yield from self._known_rids.keys()
        if self._misc_files:
            yield "misc"
    
    def __len__(self) -> int:
        has_misc = len(self._misc_files) > 0
        return len(self._known_rids) + (1 if has_misc else 0)

    def __getitem__(self, k: str) -> str:
        if k.startswith("rid_"):
            rid = k[4:].replace("_","-")
            return "".join(self.rid_assets_rows(rid))
        elif k == "misc":
            return "".join(self.misc_files_rows())
        raise KeyError(f"unsupported key: {k}")


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        return usage(argv[0])

    if not argv[2].startswith(TAG_REF_PREFIX):
        return usage(argv[0])

    owner_repo = argv[1]  # let's just trust the input from CI
    tag_name = argv[2][len(TAG_REF_PREFIX):]
    outdir = pathlib.Path(argv[3])

    um = URLMaker(owner_repo, tag_name)
    tctx = TemplateCtx(um)
    for f in outdir.glob("*"):
        name = f.name
        is_sha256 = name.endswith(".sha256")
        is_sha512 = name.endswith(".sha512")
        if is_sha256 or is_sha512:
            # we assume every archive is accompanied by these, so no need to
            # track individually
            continue

        if name.startswith("Private.SourceBuilt.Artifacts."):
            tctx.add_sb_artifacts_archive(name)
        elif name.startswith("dotnet-sdk-"):
            tctx.add_sdk_archive(name)
        elif name.startswith("dotnet-symbols-"):
            tctx.add_symbol_archive(name)
        elif name.startswith("sdk-feed-"):
            tctx.add_sdk_feed_archive(name)
        else:
            print(f"warning: unrecognized asset name {name}", file=sys.stderr)

    my_dir = pathlib.Path(__file__).parent
    tmpl_str = (my_dir / '..' / 'templates' / 'release-notes.md').read_text()
    tmpl = Template(tmpl_str)
    print(tmpl.substitute(tctx).strip('\n'))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
