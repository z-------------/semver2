import std/unittest
from std/algorithm import reversed
import std/tables

import semver2

template tail[T](l: openArray[T]): openArray[T] =
  l.toOpenArray(1, l.high)

suite "comparison":
  test "example from semver.org":
    const VersionStrs = @[
      "1.0.0-alpha",
      "1.0.0-alpha.1",
      "1.0.0-alpha.beta",
      "1.0.0-beta",
      "1.0.0-beta.2",
      "1.0.0-beta.11",
      "1.0.0-rc.1",
      "1.0.0",
    ]
    block: # forwards
      let versionStrs = VersionStrs
      var prevVersion = Semver.init(versionStrs[0])
      for versionStr in versionStrs.tail:
        let version = Semver.init(versionStr)
        check not (prevVersion == version)
        check prevVersion != version
        check prevVersion < version
        check prevVersion <= version
        check version > prevVersion
        check version >= prevVersion
        prevVersion = version
    block: # backwards
      let versionStrs = VersionStrs.reversed
      var prevVersion = Semver.init(versionStrs[0])
      for versionStr in versionStrs.tail:
        let version = Semver.init(versionStr)
        check not (prevVersion == version)
        check prevVersion != version
        check prevVersion > version
        check prevVersion >= version
        check version < prevVersion
        check version <= prevVersion
        prevVersion = version
    block: # self-comparison
      for versionStr in VersionStrs:
        let version = Semver.init(versionStr)
        check version == version
        check not (version != version)
        check not (version > version)
        check version >= version
        check not (version < version)
        check version <= version

  # from https://github.com/python-semver/python-semver/blob/b0f854da3424ed73231e4f55bac36c86b2c82987/tests/test_parsing.py
  test "version is hashable":
    let version = Semver.init("1.2.3-alpha.1.2+build.11.e0f985a")
    var t: Table[Semver, bool]
    t[version] = true

  # from https://github.com/python-semver/python-semver/blob/b0f854da3424ed73231e4f55bac36c86b2c82987/tests/test_parsing.py
  test "equal versions are equal and have equal hashes":
    let
      a = Semver.init("1.2.3-alpha.1.2+build.11.e0f985a")
      b = Semver.init("1.2.3-alpha.1.2+build.22.a589f0e")
    check a == b
    check not (a != b)
    check a.hash == b.hash

  test "non-equal versions are non-equal and have non-equal hashes":
    let
      a = Semver.init("1.2.3-alpha.1.2+build.11.e0f985a")
      b = Semver.init("3.2.1-alpha.1.2+build.11.e0f985a")
    check not (a == b)
    check a != b
    check a.hash != b.hash
