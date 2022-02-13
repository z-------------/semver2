# Copyright (C) 2022 Zack Guard
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
import ./private/parse
import std/strutils

func initSemver*(version: string): Semver =
  var ps = initParseStream(version)
  let parseResult = parseSemver(ps)
  if parseResult.isOk:
    parseResult.value
  else:
    when defined(release):
      raise newException(ValueError, "invalid SemVer")
    else:
      let errStr = version & '\n' & ' '.repeat(parseResult.error) & "^\n"
      raise newException(ValueError, "invalid SemVer:\n" & errStr)
