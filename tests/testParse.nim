import std/unittest

import semver2

# Test cases taken from https://github.com/python-semver/python-semver/blob/b0f854da3424ed73231e4f55bac36c86b2c82987/tests/test_parsing.py

template initSemver(parts: (int, int, int, seq[string], seq[string])): Semver =
  initSemver(parts[0], parts[1], parts[2], parts[3], parts[4])

suite "parsing":
  test "parse version":
    for (version, expected) in [
      ("1.2.3-alpha.1.2+build.11.e0f985a", (1, 2, 3, @["alpha", "1", "2"], @["build", "11", "e0f985a"])),
      ("1.2.3-alpha-1+build.11.e0f985a", (1, 2, 3, @["alpha-1"], @["build", "11", "e0f985a"])),
      ("0.1.0-0f", (0, 1, 0, @["0f"], @[])),
      ("0.0.0-0foo.1", (0, 0, 0, @["0foo", "1"], @[])),
      ("0.0.0-0foo.1+build.1", (0, 0, 0, @["0foo", "1"], @["build", "1"])),
    ]:
      check initSemver(version) == initSemver(expected)

  test "parse zero prerelease":
    for (version, expected) in [
      ("1.2.3-rc.0+build.0", (1, 2, 3, @["rc", "0"], @["build", "0"])),
      ("1.2.3-rc.0.0+build.0", (1, 2, 3,@["rc", "0", "0"], @["build", "0"])),
    ]:
      check initSemver(version) == initSemver(expected)

  test "raise value error for zero-prefixed versions":
    for version in ["01.2.3", "1.02.3", "1.2.03"]:
      expect ValueError:
        discard initSemver(version)
