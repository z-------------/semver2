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
import ./bump
import ./private/parse
import std/strutils
import std/sequtils
import std/enumerate

const
  X = -1

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
    version: Semver
  LooseSemver = object
    sv: Semver
    hp: Natural

func initComparator(operator: Operator; version: Semver): Comparator =
  Comparator(
    operator: operator,
    version: version
  )

func `$`(c: Comparator): string =
  $c.operator & $c.version

func `$`(cs: ComparatorSet): string =
  cs.map(`$`).join(" ")

func `$`*(r: Range): string =
  r.map(`$`).join(" || ")

template getOr0[T](l: seq[T]; idx: Natural): T =
  if idx < l.len:
    l[idx]
  else:
    0

func initLooseSemver(coreParts: seq[int] = @[]; prerelease = newSeq[string](); build = newSeq[string]()): LooseSemver =
  doAssert coreParts.len <= 3
  LooseSemver(
    hp: coreParts.len,
    sv: Semver(
      major: coreParts.getOr0(0),
      minor: coreParts.getOr0(1),
      patch: coreParts.getOr0(2),
      prerelease: prerelease,
      build: build
    )
  )

# etc #

func validateXRange(lsv: LooseSemver): bool =
  ## Return false for x-ranges with concrete parts after the first X, e.g. 1.x.3
  var foundX = false
  let hp = lsv.hp
  for i in 0..2:
    if lsv.sv[i] == X:
      foundX = true
    elif foundX and hp > i:
      return false
  true

func normalizeXRange(lsv: LooseSemver): LooseSemver =
  ## Given a validated x-range semver, replace Xs with empty
  if lsv.sv.major == X:
    initLooseSemver(prerelease = lsv.sv.prerelease, build = lsv.sv.build)
  elif lsv.sv.minor == X:
    initLooseSemver(@[lsv.sv.major], prerelease = lsv.sv.prerelease, build = lsv.sv.build)
  elif lsv.sv.patch == X:
    initLooseSemver(@[lsv.sv.major, lsv.sv.minor], prerelease = lsv.sv.prerelease, build = lsv.sv.build)
  else:
    lsv

# parsing #

const
  XChars = {'X', 'x', '*'}

func parseCharAsString[charSet: static set[char]](s: var ParseStream): R[string] =
  let c = ?parseChar[charSet](s)
  ($c).ok

func parseLooseNumericIdent(s: var ParseStream): R[string] =
  s.oneOf(parseCharAsString[XChars], parseNumericIdent)

func toIntRepr(looseCorePart: string): int =
  if looseCorePart.contains(XChars):
    X
  else:
    looseCorePart.parseInt

func parseLooseCore(s: var ParseStream): R[seq[int]] =
  let repeatResult = s.repeat(parseLooseNumericIdent, parseChar[{'.'}])
  if repeatResult.isOk:
    let resultVal = repeatResult.get
    if resultVal.len <= 3:
      resultVal.map(toIntRepr).ok
    else:
      (typeof result).err(s.pos)
  else:
    newSeq[int]().ok

func parseLooseSemver(s: var ParseStream): R[LooseSemver] =
  let
    core = ?parseLooseCore(s)
    prerelease = ?s.maybe(parsePrerelease)
    build = ?s.maybe(parseBuild)
    lsv = initLooseSemver(core, prerelease, build)
  if validateXRange(lsv):
    result = lsv.normalizeXRange().ok

func parseHyphen(s: var ParseStream): R[ComparatorSet] =
  let left = (?s.parse(parseLooseSemver)).sv
  discard ?s.parse(parseString[" - "])
  let rightRaw = ?s.parse(parseLooseSemver)

  let hp = rightRaw.hp
  let right =
    if hp < 2:
      rightRaw.sv.bumpMajor(setPrereleaseZero = true)
    elif hp < 3:
      rightRaw.sv.bumpMinor(setPrereleaseZero = true)
    else:
      rightRaw.sv
  let secondOp =
    if hp < 3:
      opLt
    else:
      opLte

  @[
    initComparator(opGte, left),
    initComparator(secondOp, right),
  ].ok

func parsePrimitive(s: var ParseStream): R[ComparatorSet] =
  let
    opStr = ?s.oneOf(parseString["<="], parseString["<"], parseString[">="], parseString[">"], parseString["="])
    op = parseEnum[Operator](opStr)
    sv = ?s.parse(parseSemverInternal)
  @[initComparator(op, sv)].ok

func parseTilde(s: var ParseStream): R[ComparatorSet] =
  discard ?s.parse(parseChar[{'~'}])
  let
    lsv = ?s.parse(parseLooseSemver)
    bumpPart =
      if lsv.hp >= 2:
        Minor
      else:
        Major
  @[
    initComparator(opGte, lsv.sv),
    initComparator(opLt, lsv.sv.bump(bumpPart, setPrereleaseZero = true)),
  ].ok

func parseCaret(s: var ParseStream): R[ComparatorSet] =
  discard ?s.parse(parseChar[{'^'}])
  let
    lsv = ?s.parse(parseLooseSemver)
    firstNonZeroIdx = block:
      var val = -1
      for (idx, part) in enumerate(lsv.sv):
        if idx >= lsv.hp:
          break
        if part != 0:
          val = idx
          break
      val
    flexIdx =
      if firstNonZeroIdx == -1:
        lsv.hp - 1
      else:
        firstNonZeroIdx
  @[
    initComparator(opGte, lsv.sv),
    initComparator(opLt, lsv.sv.bump(SemverPart(flexIdx), setPrereleaseZero = true)),
  ].ok

func parseXrange(s: var ParseStream): R[ComparatorSet] =
  let lsv = ?s.parse(parseLooseSemver)
  case lsv.hp
  of 0: # *
    @[initComparator(opGte, initSemver(0, 0, 0))].ok
  of 1: # 1.*
    @[
      initComparator(opGte, initSemver(lsv.sv.major, 0, 0)),
      initComparator(opLt, lsv.sv.bumpMajor(setPrereleaseZero = true)),
    ].ok
  of 2: # 1.2.*
    @[
      initComparator(opGte, initSemver(lsv.sv.major, lsv.sv.minor, 0)),
      initComparator(opLt, lsv.sv.bumpMinor(setPrereleaseZero = true)),
    ].ok
  else: # 1.2.3
    @[initComparator(opEq, lsv.sv)].ok

func parseSimple(s: var ParseStream): R[ComparatorSet] =
  result = s.oneOf(parsePrimitive, parseTilde, parseCaret, parseXrange)

func parseSimpleSet(s: var ParseStream): R[ComparatorSet] =
  var resultVal: ComparatorSet
  let comparators = ?s.repeat(parseSimple, parseChar[{' '}])
  for c in comparators:
    resultVal.add(c)
  resultVal.ok

func parseComparatorSet(s: var ParseStream): R[ComparatorSet] =
  s.oneOf(parseHyphen, parseSimpleSet)

func parseLogicalOr(s: var ParseStream): R[void] =
  discard ?s.many(parseChar[{' '}])
  discard ?s.parse(parseString["||"])
  discard ?s.many(parseChar[{' '}])
  result.ok

func parseRange(s: var ParseStream): R[Range] =
  let ramge = ?s.repeat(parseComparatorSet, parseLogicalOr)
  if s.isAtEnd:
    ramge.ok
  else:
    (typeof result).err(s.pos)

func parseRange(rangeStr: sink string): Range =
  var ps = initParseStream(rangeStr)
  let parseResult = parseRange(ps)
  if parseResult.isOk:
    parseResult.value
  else:
    raise newException(ValueError, "Invalid range")

# ... #

func satisfies(sv: Semver; c: Comparator): bool =
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

template coreMatches(a, b: Semver): bool =
  a.major == b.major and
  a.minor == b.minor and
  a.patch == b.patch

func satisfies(sv: Semver; comparatorSet: ComparatorSet): bool =
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

func satisfies*(sv: Semver; ramge: Range): bool =
  if ramge.len == 0:
    return true
  else:
    for comparatorSet in ramge:
      if sv.satisfies(comparatorSet):
        result = true
        break

func satisfies*(sv: Semver; rangeStr: string): bool =
  let ramge = parseRange(rangeStr)
  sv.satisfies(ramge)

template contains*(ramge: Range; sv: Semver): bool =
  sv.satisfies(ramge)

template contains*(rangeStr: string; sv: Semver): bool =
  sv.satisfies(rangeStr)

func initRange*(rangeStr: string): Range =
  parseRange(rangeStr)
