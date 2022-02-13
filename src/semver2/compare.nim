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

import ./types
import std/strutils

template empty[T](l: seq[T]): bool =
  l.len == 0

func isOnlyDigits(s: string): bool =
  for c in s:
    if c notin {'0'..'9'}:
      return false
  true

func compare(a, b: Semver): int =
  if a.major != b.major:
    a.major - b.major
  elif a.minor != b.minor:
    a.minor - b.minor
  elif a.patch != b.patch:
    a.patch - b.patch
  elif not a.prerelease.empty and b.prerelease.empty:
    -1
  elif a.prerelease.empty and not b.prerelease.empty:
    1
  else:
    for i in 0..min(a.prerelease.high, b.prerelease.high):
      let
        aPr = a.prerelease[i]
        bPr = b.prerelease[i]
      if isOnlyDigits(aPr) and isOnlyDigits(bPr):
        let diff = parseInt(aPr) - parseInt(bPr)
        if diff != 0:
          return diff
      elif isOnlyDigits(aPr) and not isOnlyDigits(bPr):
        return -1
      elif not isOnlyDigits(aPr) and isOnlyDigits(bPr):
        return 1
      else:
        let diff = cmp(aPr, bPr)
        if diff != 0:
          return diff
    a.prerelease.len - b.prerelease.len

func `<`*(a, b: Semver): bool =
  compare(a, b) < 0

func `<=`*(a, b: Semver): bool =
  compare(a, b) <= 0

func `==`*(a, b: Semver): bool =
  compare(a, b) == 0
