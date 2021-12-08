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

from std/strutils import join
import std/hashes

type
  SemVer* = object
    major*: int
    minor*: int
    patch*: int
    prerelease*: seq[string]
    build*: seq[string]

func initSemVer*(major: Natural; minor, patch = 0.Natural; prerelease, build = newSeq[string]()): SemVer =
  SemVer(
    major: major,
    minor: minor,
    patch: patch,
    prerelease: prerelease,
    build: build
  )

func `$`*(sv: SemVer): string =
  result = $sv.major & '.' & $sv.minor & '.' & $sv.patch
  if sv.prerelease.len > 0:
    result.add('-' & sv.prerelease.join("."))
  if sv.build.len > 0:
    result.add('+' & sv.build.join("."))

func hash*(sv: SemVer): Hash =
  var h: Hash
  h = h !& sv.major.hash
  h = h !& sv.minor.hash
  h = h !& sv.patch.hash
  h = h !& sv.prerelease.hash
  # build intentionally excluded
  !$h
