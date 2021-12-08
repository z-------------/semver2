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
import std/options

type
  PartialBehavior* = enum
    pbDisallow # partial semvers fail to parse
    pbZero # partial semvers have their empty parts replaced with 0
    pbUp # hard to explain... 2.3 -> 2.4.0-0 
  OptionalSemVer* = object
    major*: Option[int]
    minor*: Option[int]
    patch*: Option[int]
    prerelease*: seq[string]
    build*: seq[string]

const
  SemVerParser* = peg("semVer", osv: OptionalSemVer):
    semVer <- versionCore * ?('-' * prerelease) * ?('+' * build) * !1

    versionCore <- major * ?('.' * minor * ?('.' * patch))
    major <- numericIdent:
      osv.major = parseInt($0).some
    minor <- numericIdent:
      osv.minor = parseInt($0).some
    patch <- numericIdent:
      osv.patch = parseInt($0).some

    prerelease <- prereleaseIdent * *('.' * prereleaseIdent)
    prereleaseIdent <- (alphanumericIdent | numericIdent):
      osv.prerelease.add($0)

    build <- buildIdent * *('.' * buildIdent)
    buildIdent <- (alphanumericIdent | digits):
      osv.build.add($0)

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

proc parseSemVer*(version: string): OptionalSemVer =
  let parseResult = SemVerParser.match(version, result)
  if not parseResult.ok:
    raise newException(ValueError, "invalid SemVer")

proc parseSemVer*(version: string; partialBehavior: PartialBehavior): (SemVer, OptionalSemVer) =
  let osv = parseSemVer(version)
  var sv = initSemVer(osv.major.get(0), osv.minor.get(0), osv.patch.get(0), osv.prerelease, osv.build)

  case partialBehavior
  of pbDisallow:
    if osv.minor.isNone:
      raise newException(ValueError, "invalid SemVer: missing minor")
    elif osv.patch.isNone:
      raise newException(ValueError, "invalid SemVer: missing patch")
  of pbZero:
    discard
  of pbUp:
    if osv.minor.isNone:
      sv = sv.bumpMajor()
      sv.prerelease = @["0"]
    elif osv.patch.isNone:
      sv = sv.bumpMinor()
      sv.prerelease = @["0"]
  (sv, osv)

proc initSemVer*(version: string; partialBehavior = pbDisallow): SemVer =
  let (sv, _) = parseSemVer(version, partialBehavior)
  sv
