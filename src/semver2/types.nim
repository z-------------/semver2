# Copyright (C) 2021 Zack Guard
# 
# This file is part of semver2.
# 
# semver2 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# semver2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with semver2.  If not, see <http://www.gnu.org/licenses/>.

from std/strutils import join, strip
import std/hashes

type
  SemverPart* = enum
    Major = 0
    Minor = 1
    Patch = 2
  Semver* = object
    major*: int
    minor*: int
    patch*: int
    prerelease*: seq[string]
    build*: seq[string]

func initSemver*(major = 0.Natural; minor = 0.Natural; patch = 0.Natural; prerelease = newSeq[string](); build = newSeq[string]()): Semver =
  Semver(
    major: major,
    minor: minor,
    patch: patch,
    prerelease: prerelease,
    build: build
  )

template initSemver*(parts: (int, int, int, seq[string], seq[string])): Semver =
  initSemver(parts[0], parts[1], parts[2], parts[3], parts[4])

func `[]`*(sv: Semver; idx: range[0..2]): int =
  case idx
  of 0:
    sv.major
  of 1:
    sv.minor
  of 2:
    sv.patch

func `$`*(sv: Semver): string =
  result = $sv.major & '.' & $sv.minor & '.' & $sv.patch
  if sv.prerelease.len > 0:
    result.add('-' & sv.prerelease.join("."))
  if sv.build.len > 0:
    result.add('+' & sv.build.join("."))

func hash*(sv: Semver): Hash =
  var h: Hash
  h = h !& sv.major.hash
  h = h !& sv.minor.hash
  h = h !& sv.patch.hash
  h = h !& sv.prerelease.hash
  # build intentionally excluded
  !$h

iterator items*(sv: Semver): int =
  yield sv.major
  yield sv.minor
  yield sv.patch

func clean*(versionStr: string): string =
  let stripped = versionStr.strip()
  if stripped.len > 0 and stripped[0] in {'V', 'v'}:
    stripped[1..^1]
  else:
    stripped
