import std/unittest
from std/algorithm import reversed

import semver2

template tail[T](l: seq[T]): seq[T] =
  l[1..l.high]

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
      var prevVersion = initSemVer(versionStrs[0])
      for versionStr in versionStrs.tail:
        let version = initSemVer(versionStr)
        check prevVersion < version
        check version > prevVersion
        prevVersion = version
    block: # backwards
      let versionStrs = VersionStrs.reversed
      var prevVersion = initSemVer(versionStrs[0])
      for versionStr in versionStrs.tail:
        let version = initSemVer(versionStr)
        check prevVersion > version
        check version < prevVersion
        prevVersion = version
    block: # self-comparison
      for versionStr in VersionStrs:
        let version = initSemVer(versionStr)
        check version == version
        check version >= version
        check version <= version
        check not (version > version)
        check not (version < version)
