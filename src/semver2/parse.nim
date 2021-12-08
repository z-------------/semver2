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
  ParseState = object
    sv: SemVer
    hasMajor: bool
    hasMinor: bool
    hasPatch: bool

const
  SemVerParser* = peg("semVer", ps: ParseState):
    semVer <- versionCore * ?('-' * prerelease) * ?('+' * build) | ""

    versionCore <- major * ?('.' * minor * ?('.' * patch))
    major <- numericIdent:
      ps.sv.major = parseInt($0)
      ps.hasMajor = true
    minor <- numericIdent:
      ps.sv.minor = parseInt($0)
      ps.hasMinor = true
    patch <- numericIdent:
      ps.sv.patch = parseInt($0)
      ps.hasPatch = true

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

proc initSemVer*(version: string; strict = true): SemVer =
  var parseState: ParseState
  let parseResult = SemVerParser.match(version, parseState)
  if not parseResult.ok or parseResult.matchLen != version.len:
    raise newException(ValueError, "invalid SemVer")
  if strict:
    if not parseState.hasMajor:
      raise newException(ValueError, "invalid SemVer: missing major")
    elif not parseState.hasMinor:
      raise newException(ValueError, "invalid SemVer: missing minor")
    elif not parseState.hasPatch:
      raise newException(ValueError, "invalid SemVer: missing patch")
  parseState.sv
