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
import pkg/npeg
import std/strutils
import std/sequtils

type
  Operator = enum
    opEq = "="
    opLte = "<="
    opLt = "<"
    opGte = ">="
    opGt = ">"
  Range* = object
    comparatorSets: seq[ComparatorSet]
  ComparatorSet = object
    comparators: seq[Comparator]
  Comparator = object
    operator: Operator
    version: SemVer
  ParseState = object
    curComparatorSet: ComparatorSet
    r: Range

func initComparator(operator: Operator; version: SemVer): Comparator =
  Comparator(
    operator: operator,
    version: version
  )

func `$`(c: Comparator): string =
  $c.operator & $c.version

func `$`(cs: ComparatorSet): string =
  cs.comparators.map(`$`).join(" ")

func `$`(r: Range): string =
  r.comparatorSets.map(`$`).join(" || ")

proc parsePrimitiveComparator(c: string): Comparator =
  var isParsed = false
  for op in Operator:
    if c.startsWith($op):
      let verStr = c[($op).len..c.high]
      result = initComparator(op, initSemVer(verStr, pbZero))
      isParsed = true
      break
  if not isParsed:
    result = initComparator(opEq, initSemVer(c, pbZero))

const RangeParser = peg("ramge", ps: ParseState):
  ramge <- comparatorSet * *(logicalOr * comparatorSet) * !1
  logicalOr <- *' ' * "||" * *' '
  comparatorSet <- hyphen | simple * *(' ' * simple) | "":
    ps.r.comparatorSets.add(ps.curComparatorSet)
    ps.curComparatorSet.reset()
  hyphen <- >partial * " - " * >partial:
    let
      sv0 = initSemVer($1, pbZero)
      (sv1, hp1) = parseSemVer($2, pbUp)
    let secondOp =
      if hpMinor notin hp1 or hpPatch notin hp1:
        opLt
      else:
        opLte
    ps.curComparatorSet.comparators.add(initComparator(opGte, sv0))
    ps.curComparatorSet.comparators.add(initComparator(secondOp, sv1))
  simple <- primitive | literal | tilde | caret
  primitive <- ("<=" | '<' | ">=" | '>' | '=') * partial:
    ps.curComparatorSet.comparators.add(parsePrimitiveComparator($0))
  literal <- partial:
    ps.curComparatorSet.comparators.add(initComparator(opEq, initSemVer($0, pbZero)))
  partial <- xr * ?('.' * xr * ?('.' * xr * ?qualifier))
  xr <- 'x' | 'X' | '*' | nr
  nr <- '0' | {'1'..'9'} * *{'0'..'9'}
  tilde <- '~' * >partial
  caret <- '^' * >partial
  qualifier <- ?('-' * pre) * ?('+' * build)
  pre <- parts
  build <- parts
  parts <- part * *('.' * part)
  part <- nr | +{'-', '0'..'9', 'A'..'Z', 'a'..'z'}

proc parseRange(rangeStr: string): Range =
  var ps: ParseState
  let parseResult = RangeParser.match(rangeStr, ps)
  if not parseResult.ok:
    raise newException(ValueError, "invalid range")
  ps.r

func satisfies(sv: SemVer; c: Comparator): bool =
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

func satisfies(sv: SemVer; comparatorSet: ComparatorSet): bool =
  result = true
  for c in comparatorSet.comparators:
    if not sv.satisfies(c):
      result = false
      break

func satisfies*(sv: SemVer; ramge: Range): bool =
  if ramge.comparatorSets.len == 0:
    return true
  else:
    for comparatorSet in ramge.comparatorSets:
      if sv.satisfies(comparatorSet):
        result = true
        break

proc satisfies*(sv: SemVer; rangeStr: string): bool =
  let ramge = parseRange(rangeStr)
  sv.satisfies(ramge)

template contains*(ramge: Range; sv: SemVer): bool =
  sv.satisfies(ramge)

template contains*(rangeStr: string; sv: SemVer): bool =
  sv.satisfies(rangeStr)

# TODO: fully implement the range rules
