import std/unittest

import semver2

template addJunk(versionStr: string): string =
  "      v" & versionStr & "      "

# Test cases taken from https://github.com/python-semver/python-semver/blob/b0f854da3424ed73231e4f55bac36c86b2c82987/tests/test_parsing.py

suite "parsing":
  test "parse version":
    for (version, expected) in [
      ("1.2.3-alpha.1.2+build.11.e0f985a", (1, 2, 3, @["alpha", "1", "2"], @["build", "11", "e0f985a"])),
      ("11.222.3333-alpha.12.23+build.11.e0f985a", (11, 222, 3333, @["alpha", "12", "23"], @["build", "11", "e0f985a"])),
      ("1.2.3-alpha-1+build.11.e0f985a", (1, 2, 3, @["alpha-1"], @["build", "11", "e0f985a"])),
      ("0.1.0-0f", (0, 1, 0, @["0f"], @[])),
      ("0.0.0-0foo.1", (0, 0, 0, @["0foo", "1"], @[])),
      ("0.0.0-0foo.1+build.1", (0, 0, 0, @["0foo", "1"], @["build", "1"])),
    ]:
      check Semver.init(version) == Semver.init(expected)
      check Semver.init(version.addJunk.clean) == Semver.init(expected)

  test "parse zero prerelease":
    for (version, expected) in [
      ("1.2.3-rc.0+build.0", (1, 2, 3, @["rc", "0"], @["build", "0"])),
      ("1.2.3-rc.0.0+build.0", (1, 2, 3,@["rc", "0", "0"], @["build", "0"])),
    ]:
      check Semver.init(version) == Semver.init(expected)
      check Semver.init(version.addJunk.clean) == Semver.init(expected)

  test "raise value error for invalid versions":
    const InvalidVersionStrs = [
      # leading 0
      "01.2.3",
      "1.02.3",
      "1.2.03",
      # non-digits
      "a.2.3",
      "1.b.3",
      "1.2.c",
      "1.2.x",
    ]
    for version in InvalidVersionStrs:
      expect ValueError:
        discard Semver.init(version)

  test "parse version with coercion":
    for (version, expected) in [
      ("1.2.3.4-alpha.1.2+build.11.e0f985a", (1, 2, 3, @["alpha", "1", "2"], @["4", "build", "11", "e0f985a"])),
      ("1.2-alpha-1+build.11.e0f985a", (1, 2, 0, @["alpha-1"], @["build", "11", "e0f985a"])),
      ("1-alpha-1+build.11.e0f985a", (1, 0, 0, @["alpha-1"], @["build", "11", "e0f985a"])),
      ("0.1-0f", (0, 1, 0, @["0f"], @[])),
      ("0.1.0.2-0f", (0, 1, 0, @["0f"], @["2"])),
      ("0-0foo.1", (0, 0, 0, @["0foo", "1"], @[])),
      ("0.0-0foo.1+build.1", (0, 0, 0, @["0foo", "1"], @["build", "1"])),
    ]:
      check Semver.init(version, coerce = true) == Semver.init(expected)
      check Semver.init(version.addJunk, coerce = true) == Semver.init(expected)
