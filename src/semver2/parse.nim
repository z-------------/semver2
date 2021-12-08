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
import ./bump
import pkg/npeg
import std/strutils

type
  PartialBehavior* = enum
    pbDisallow # partial semvers fail to parse
    pbZero # partial semvers have their empty parts replaced with 0
    pbUp # hard to explain... 2.3 -> 2.4.0-0
  HasPart* = enum
    hpMajor
    hpMinor
    hpPatch
  ParseState = object
    sv: SemVer
    hasParts: set[HasPart]

const
  SemVerParser = peg("semVer", ps: ParseState):
    semVer <- versionCore * ?('-' * prerelease) * ?('+' * build) * !1

    versionCore <- major * ?('.' * minor * ?('.' * patch))
    major <- numericIdent:
      ps.sv.major = parseInt($0)
      ps.hasParts.incl(hpMajor)
    minor <- numericIdent:
      ps.sv.minor = parseInt($0)
      ps.hasParts.incl(hpMinor)
    patch <- numericIdent:
      ps.sv.patch = parseInt($0)
      ps.hasParts.incl(hpPatch)

    prerelease <- prereleaseIdent * *('.' * prereleaseIdent)
    prereleaseIdent <- (alphanumericIdent | numericIdent):
      ps.sv.prerelease.add($0)

    build <- buildIdent * *('.' * buildIdent)
    buildIdent <- (alphanumericIdent | digits):
      ps.sv.build.add($0)

    alphanumericIdent <-
      nonDigit * *identChar |
      +(identChar - nonDigit) * nonDigit * *identChar
    numericIdent <- '0' | positiveDigit * *digits
    identChar <- digit | nonDigit
    nonDigit <- letter | '-'
    digits <- +digit
    digit <- '0' | positiveDigit
    positiveDigit <- {'1'..'9'}
    letter <- Alpha

proc parseSemVer*(version: string): (SemVer, set[HasPart]) =
  var ps: ParseState
  let parseResult = SemVerParser.match(version, ps)
  if not parseResult.ok:
    raise newException(ValueError, "invalid SemVer")
  (ps.sv, ps.hasParts)

proc parseSemVer*(version: string; partialBehavior: PartialBehavior): (SemVer, set[HasPart]) =
  result = parseSemVer(version)

  case partialBehavior
  of pbDisallow:
    if hpMinor notin result[1]:
      raise newException(ValueError, "invalid SemVer: missing minor")
    elif hpPatch notin result[1]:
      raise newException(ValueError, "invalid SemVer: missing patch")
  of pbZero:
    discard
  of pbUp:
    if hpMinor notin result[1]:
      result[0] = result[0].bumpMajor()
      result[0].prerelease = @["0"]
    elif hpPatch notin result[1]:
      result[0] = result[0].bumpMinor()
      result[0].prerelease = @["0"]

proc initSemVer*(version: string; partialBehavior = pbDisallow): SemVer =
  let (sv, _) = parseSemVer(version, partialBehavior)
  sv
