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

func bumpMajor*(sv: SemVer; setPrereleaseZero = false): SemVer =
  result = initSemVer(sv.major + 1)
  if setPrereleaseZero:
    result.prerelease = @["0"]

func bumpMinor*(sv: SemVer; setPrereleaseZero = false): SemVer =
  result = initSemVer(sv.major, sv.minor + 1)
  if setPrereleaseZero:
    result.prerelease = @["0"]

func bumpPatch*(sv: SemVer; setPrereleaseZero = false): SemVer =
  result = initSemVer(sv.major, sv.minor, sv.patch + 1)
  if setPrereleaseZero:
    result.prerelease = @["0"]

func bump*(sv: SemVer; idx: range[0..2]; setPrereleaseZero = false): SemVer =
  case idx
  of 0:
    sv.bumpMajor(setPrereleaseZero)
  of 1:
    sv.bumpMinor(setPrereleaseZero)
  of 2:
    sv.bumpPatch(setPrereleaseZero)

# TODO: bumpPrerelease, bumpBuild
