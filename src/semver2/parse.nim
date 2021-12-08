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

const
  SemVerParser* = peg("semVer", sv: SemVer):
    semVer <- versionCore * ?('-' * prerelease) * ?('+' * build)

    versionCore <- major * '.' * minor * '.' * patch
    major <- numericIdent:
      sv.major = parseInt($0)
    minor <- numericIdent:
      sv.minor = parseInt($0)
    patch <- numericIdent:
      sv.patch = parseInt($0)

    prerelease <- prereleaseIdent * *('.' * prereleaseIdent)
    prereleaseIdent <- (alphanumericIdent | numericIdent):
      sv.prerelease.add($0)

    build <- buildIdent * *('.' * buildIdent)
    buildIdent <- (alphanumericIdent | digits):
      sv.build.add($0)

    alphanumericIdent <-
      nonDigit * *identChars |
      identChars * nonDigit * *identChars
    numericIdent <- '0' | positiveDigit * *digits
    identChars <- +identChar
    identChar <- digit | nonDigit
    nonDigit <- letter | '-'
    digits <- +digit
    digit <- '0' | positiveDigit
    positiveDigit <- {'1'..'9'}
    letter <- Alpha

proc initSemVer*(version: string): SemVer =
  let parseResult = SemVerParser.match(version, result)
  if not parseResult.ok:
    raise newException(CatchableError, "invalid SemVer")
