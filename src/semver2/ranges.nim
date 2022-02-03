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
import ./parse {.all.}
import ./bump
import pkg/npeg
import std/strutils
import std/sequtils
import std/enumerate

# types #

type
  Operator = enum
    opEq = "="
    opLte = "<="
    opLt = "<"
    opGte = ">="
    opGt = ">"
  Range* = seq[ComparatorSet]
  ComparatorSet = seq[Comparator]
  Comparator = object
    operator: Operator
    version: SemVer

func initComparator(operator: Operator; version: SemVer): Comparator =
  Comparator(
    operator: operator,
    version: version
  )

func initComparatorSet(): ComparatorSet =
  newSeq[Comparator]()

func `$`(c: Comparator): string =
  $c.operator & $c.version

func `$`(cs: ComparatorSet): string =
  cs.map(`$`).join(" ")

func `$`(r: Range): string =
  r.map(`$`).join(" || ")

# parsing #

type
  ParseState = object
    r: Range
    comparatorSet: ComparatorSet
    curPs, prevPs: parse.ParseState

func validateXRange(sv: SemVer; hp: int): bool =
  ## Return false for x-ranges with concrete parts after the first X, e.g. 1.x.3
  var foundX = false
  for i in 0..2:
    if sv[i] == X:
      foundX = true
    elif foundX and hp > i:
      return false
  true

func normalizeXRange(sv: SemVer; hp: int): (SemVer, int) =
  ## Given a validated x-range semver, replace Xs with empty
  if sv.major == X:
    (initSemVer(prerelease = sv.prerelease, build = sv.build), 0)
  elif sv.minor == X:
    (initSemVer(sv.major, prerelease = sv.prerelease, build = sv.build), 1)
  elif sv.patch == X:
    (initSemVer(sv.major, sv.minor, prerelease = sv.prerelease, build = sv.build), 2)
  else:
    (sv, hp)

# parsing doesn't work correctly at compile time if I use reset() instead of explicitly constructing new objects for ComparatorSet, SemVer, and set[HasPart]
const RangeParser = peg("ramge", ps: ParseState):
  ramge <- comparatorSet * *(logicalOr * comparatorSet) * !1
  logicalOr <- *' ' * "||" * *' '
  comparatorSet <- hyphen | simple * *(' ' * simple) | "":
    ps.r.add(ps.comparatorSet)
    ps.comparatorSet = initComparatorSet()
  simple <- primitive | tilde | caret | xpartial

  primitive <- >("<=" | '<' | ">=" | '>' | '=') * partial:
    ps.comparatorSet.add:
      let op = parseEnum[Operator]($1, default = opEq)
      @[initComparator(op, ps.curPs.sv)]

  # X.Y.Z - A.B.C
  hyphen <- >partial * " - " * >partial:
    ps.comparatorSet.add:
      let hp = ps.curPs.hasParts
      if hp < 2:
        ps.curPs.sv = ps.curPs.sv.bumpMajor(setPrereleaseZero = true)
      elif hp < 3:
        ps.curPs.sv = ps.curPs.sv.bumpMinor(setPrereleaseZero = true)
      let secondOp =
        if hp < 3:
          opLt
        else:
          opLte
      @[
        initComparator(opGte, ps.prevPs.sv),
        initComparator(secondOp, ps.curPs.sv),
      ]

  # 1.2.x
  xpartial <- partial:
    validate validateXRange(ps.curPs.sv, ps.curPs.hasParts)
    ps.comparatorSet.add:
      let (sv, hp) = normalizeXRange(ps.curPs.sv, ps.curPs.hasParts)
      case hp
      of 0: # *
        @[initComparator(opGte, initSemVer(0, 0, 0))]
      of 1: # 1.*
        @[
          initComparator(opGte, initSemVer(sv.major, 0, 0)),
          initComparator(opLt, sv.bumpMajor(setPrereleaseZero = true)),
        ]
      of 2: # 1.2.*
        @[
          initComparator(opGte, initSemVer(sv.major, sv.minor, 0)),
          initComparator(opLt, sv.bumpMinor(setPrereleaseZero = true)),
        ]
      else: # 1.2.3
        @[initComparator(opEq, sv)]

  # ~1.2.3
  tilde <- '~' * >partial:
    let
      sv = ps.curPs.sv
      hp = ps.curPs.hasParts
      bumpIdx =
        if hp >= 2:
          1
        else:
          0
    ps.comparatorSet.add(@[
      initComparator(opGte, sv),
      initComparator(opLt, sv.bump(bumpIdx, setPrereleaseZero = true)),
    ])

  # ^1.2.3
  caret <- '^' * >partial:
    validate validateXRange(ps.curPs.sv, ps.curPs.hasParts)
    let
      (sv, hp) = normalizeXRange(ps.curPs.sv, ps.curPs.hasParts)
      firstNonZeroIdx = block:
        var val = -1
        for (idx, part) in enumerate(sv):
          if idx >= hp:
            break
          if part != 0:
            val = idx
            break
        val
    let flexIdx =
      if firstNonZeroIdx == -1:
        hp - 1
      else:
        firstNonZeroIdx
    ps.comparatorSet.add(@[
      initComparator(opGte, sv),
      initComparator(opLt, sv.bump(flexIdx, setPrereleaseZero = true)),
    ])

  partial <- semVer.semVer
  semVer.major <- >semVer.major:
    swap(ps.prevPs, ps.curPs)
    ps.curPs.sv = SemVer()
    ps.curPs.hasParts = 0
    ps.curPs.sv.major = parseNumPart($1)
    inc ps.curPs.hasParts
  semVer.minor <- >semVer.minor:
    ps.curPs.sv.minor = parseNumPart($1)
    inc ps.curPs.hasParts
  semVer.patch <- >semVer.patch:
    ps.curPs.sv.patch = parseNumPart($1)
    inc ps.curPs.hasParts
  semVer.prereleaseIdent <- >semVer.prereleaseIdent:
    ps.curPs.sv.prerelease.add($1)
  semVer.buildIdent <- >semVer.buildIdent:
    ps.curPs.sv.build.add($1)

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

template coreMatches(a, b: SemVer): bool =
  a.major == b.major and
  a.minor == b.minor and
  a.patch == b.patch

func satisfies(sv: SemVer; comparatorSet: ComparatorSet): bool =
  let hasPrerelease = sv.prerelease.len > 0
  var
    naiveResult = true
    matchingComparatorHasPrerelease = false
  for c in comparatorSet:
    if not matchingComparatorHasPrerelease and c.version.coreMatches(sv) and c.version.prerelease.len > 0:
      matchingComparatorHasPrerelease = true
    if not sv.satisfies(c):
      naiveResult = false
      break
  naiveResult and (not hasPrerelease or (hasPrerelease and matchingComparatorHasPrerelease))

func satisfies*(sv: SemVer; ramge: Range): bool =
  if ramge.len == 0:
    return true
  else:
    for comparatorSet in ramge:
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

proc initRange*(rangeStr: string): Range =
  parseRange(rangeStr)

# TODO: fully implement the range rules
