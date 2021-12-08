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
import ./compare
import ./parse
import std/strutils
import std/sequtils

type
  Operator = enum
    opEq = "="
    opLte = "<="
    opLt = "<"
    opGte = ">="
    opGt = ">"
  Comparator = object
    operator: Operator
    version: SemVer

func initComparator(operator: Operator; version: SemVer): Comparator =
  Comparator(
    operator: operator,
    version: version
  )

proc parseComparator(c: string): Comparator =
  var isParsed = false
  for op in Operator:
    if c.startsWith($op):
      let verStr = c[($op).len..c.high]
      result = initComparator(op, initSemVer(verStr))
      isParsed = true
      break
  if not isParsed:
    result = initComparator(opEq, initSemVer(c))

func satisfiesComparator(sv: SemVer; c: Comparator): bool =
  case c.operator
  of opEq:
    sv == c.version
  of opLte:
    sv <= c.version
  of opLt:
    sv < c.version
  of opGte:
    sv >= c.version
  of opGt:
    sv > c.version

proc satisfiesComparatorSet(sv: SemVer; comparatorSet: string): bool =
  result = true
  let comparators = comparatorSet.split(" ").filterIt(it.len > 0).mapIt(it.strip)
  for cStr in comparators:
    let c = parseComparator(cStr)
    if not sv.satisfiesComparator(c):
      result = false
      break

proc satisfies*(sv: SemVer; theRange: string): bool =
  let comparatorSets = theRange.split("||").mapIt(it.strip)
  if comparatorSets.len == 0:
    return true
  else:
    for comparatorSet in comparatorSets:
      if sv.satisfiesComparatorSet(comparatorSet):
        result = true
        break
