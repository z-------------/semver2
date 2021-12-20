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
import pkg/npeg
import std/strutils

type
  PartialBehavior* = enum
    pbDisallow # partial semvers fail to parse
    pbZero # partial semvers have their empty parts replaced with 0
  ParseState = object
    sv*: SemVer
    hasParts*: int

const
  X* = -1

template parseNumPart(numPart: string): int =
  case numPart
  of "X", "x", "*":
    X
  else:
    parseInt(numPart)

grammar("semVer"):
  semVer <- ?(versionCore * ?('-' * prerelease) * ?('+' * build))

  versionCore <- major * ?('.' * minor * ?('.' * patch))
  versionCorePart <- xIdent | numericIdent
  major <- versionCorePart
  minor <- versionCorePart
  patch <- versionCorePart

  prerelease <- prereleaseIdent * *('.' * prereleaseIdent)
  prereleaseIdent <- (alphanumericIdent | numericIdent)

  build <- buildIdent * *('.' * buildIdent)
  buildIdent <- (alphanumericIdent | digits)

  xIdent <- {'X', 'x', '*'}
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

const SemVerParser = peg("semVer", ps: ParseState):
  semVer <- semVer.semVer * !1

  semVer.major <- >semVer.major:
    ps.sv.major = parseNumPart($1)
    inc ps.hasParts
  semVer.minor <- >semVer.minor:
    ps.sv.minor = parseNumPart($1)
    inc ps.hasParts
  semVer.patch <- >semVer.patch:
    ps.sv.patch = parseNumPart($1)
    inc ps.hasParts

  semVer.prereleaseIdent <- >semVer.prereleaseIdent:
    ps.sv.prerelease.add($1)
  semVer.buildIdent <- >semVer.buildIdent:
    ps.sv.build.add($1)

proc parseSemVer*(version: string): (SemVer, int) =
  var ps: ParseState
  let parseResult = SemVerParser.match(version, ps)
  if not parseResult.ok:
    raise newException(ValueError, "invalid SemVer")
  if ps.hasParts == 0:
    raise newException(ValueError, "empty SemVer")
  if ps.sv.major == X or ps.sv.minor == X or ps.sv.patch == X:
    raise newException(ValueError, "X, x, and * are not allowed in a concrete SemVer")
  (ps.sv, ps.hasParts)

proc parseSemVer*(version: string; partialBehavior: PartialBehavior): (SemVer, int) =
  result = parseSemVer(version)

  case partialBehavior
  of pbDisallow:
    if result[1] < 3:
      raise newException(ValueError, "invalid SemVer: missing minor and/or patch")
  of pbZero:
    discard

proc initSemVer*(version: string; partialBehavior = pbDisallow): SemVer =
  let (sv, _) = parseSemVer(version, partialBehavior)
  sv
