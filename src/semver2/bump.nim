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

{.push raises: [].}

func bumpMajor*(sv: Semver; setPrereleaseZero = false): Semver =
  result = Semver.init(sv.major + 1)
  if setPrereleaseZero:
    result.prerelease = @["0"]

func bumpMinor*(sv: Semver; setPrereleaseZero = false): Semver =
  result = Semver.init(sv.major, sv.minor + 1)
  if setPrereleaseZero:
    result.prerelease = @["0"]

func bumpPatch*(sv: Semver; setPrereleaseZero = false): Semver =
  result = Semver.init(sv.major, sv.minor, sv.patch + 1)
  if setPrereleaseZero:
    result.prerelease = @["0"]

func bump*(sv: Semver; part: SemverPart; setPrereleaseZero = false): Semver =
  case part
  of Major:
    sv.bumpMajor(setPrereleaseZero)
  of Minor:
    sv.bumpMinor(setPrereleaseZero)
  of Patch:
    sv.bumpPatch(setPrereleaseZero)

# TODO: bumpPrerelease, bumpBuild

{.pop raises.}
