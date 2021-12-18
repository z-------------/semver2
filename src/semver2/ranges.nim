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

func has(hp: set[HasPart]; idx: range[0..2]): bool =
  case idx
  of 0:
    hpMajor in hp
  of 1:
    hpMinor in hp
  of 2:
    hpPatch in hp

func validateXRange(sv: SemVer; hp: set[HasPart]): bool =
  ## Return false for x-ranges with concrete parts after the first X, e.g. 1.x.3
  var foundX = false
  for i in 0..2:
    if sv[i] == X:
      foundX = true
    elif foundX and hp.has(i):
      return false
  true

func normalizeXRange(sv: SemVer; hp: set[HasPart]): (SemVer, set[HasPart]) =
  ## Given a normalized x-range semver, replace Xs with empty
  if sv.major == X:
    (initSemVer(prerelease = sv.prerelease, build = sv.build), {})
  elif sv.minor == X:
    (initSemVer(sv.major, prerelease = sv.prerelease, build = sv.build), {hpMajor})
  elif sv.patch == X:
    (initSemVer(sv.major, sv.minor, prerelease = sv.prerelease, build = sv.build), {hpMajor, hpMinor})
  else:
    (sv, hp)

# parsing doesn't work correctly at compile time if I use reset() instead of explicitly constructing new objects for ComparatorSet, SemVer, and set[HasPart]
const RangeParser = peg("ramge", ps: ParseState):
  ramge <- comparatorSet * *(logicalOr * comparatorSet) * !1
  logicalOr <- *' ' * "||" * *' '
  comparatorSet <- hyphen | simple * *(' ' * simple) | "":
    ps.r.add(ps.comparatorSet)
    ps.comparatorSet = initComparatorSet()
  simple <- primitive | xpartial | tilde | caret

  primitive <- >("<=" | '<' | ">=" | '>' | '=') * partial:
    ps.comparatorSet.add:
      let op = parseEnum[Operator]($1, default = opEq)
      @[initComparator(op, ps.curPs.sv)]

  # X.Y.Z - A.B.C
  hyphen <- >partial * " - " * >partial:
    ps.comparatorSet.add:
      let curHp = ps.curPs.hasParts
      if hpMinor notin curHp:
        ps.curPs.sv = ps.curPs.sv.bumpMajor(setPrereleaseZero = true)
      elif hpPatch notin curHp:
        ps.curPs.sv = ps.curPs.sv.bumpMinor(setPrereleaseZero = true)
      let secondOp =
        if ps.curPs.hasParts != {hpMajor, hpMinor, hpPatch}:
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
      if hp == {}: # *
        @[initComparator(opGte, initSemVer(0, 0, 0))]
      elif hp == {hpMajor}: # 1.*
        @[
          initComparator(opGte, initSemVer(sv.major, 0, 0)),
          initComparator(opLt, initSemVer(sv.major + 1, 0, 0, @["0"])),
        ]
      elif hp == {hpMajor, hpMinor}: # 1.2.*
        @[
          initComparator(opGte, initSemVer(sv.major, sv.minor, 0)),
          initComparator(opLt, initSemVer(sv.major, sv.minor + 1, 0, @["0"])),
        ]
      else: # 1.2.3
        @[initComparator(opEq, sv)]

  # ~1.2.3
  tilde <- '~' * >partial

  # ^1.2.3
  caret <- '^' * >partial

  partial <- semVer.semVer
  semVer.major <- >semVer.major:
    swap(ps.prevPs, ps.curPs)
    ps.curPs.sv = SemVer()
    ps.curPs.hasParts = {}
    ps.curPs.sv.major = parseNumPart($1)
    ps.curPs.hasParts.incl(hpMajor)
  semVer.minor <- >semVer.minor:
    ps.curPs.sv.minor = parseNumPart($1)
    ps.curPs.hasParts.incl(hpMinor)
  semVer.patch <- >semVer.patch:
    ps.curPs.sv.patch = parseNumPart($1)
    ps.curPs.hasParts.incl(hpPatch)
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

func satisfies(sv: SemVer; comparatorSet: ComparatorSet): bool =
  result = true
  for c in comparatorSet:
    if not sv.satisfies(c):
      result = false
      break

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

# TODO: fully implement the range rules
