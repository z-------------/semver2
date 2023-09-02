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

import ../types
import pkg/results
import std/strutils

export results

# result type #

type
  R*[T] = Result[T, Natural]

# ParseStream #

type
  ParseStream* = object
    data: string
    pos*: Natural

func initParseStream*(data: sink string): ParseStream =
  ParseStream(data: data)

func isAtEnd*(s: ParseStream): bool =
  s.pos == s.data.len

func formatState*(s: ParseStream): string =
  result.add(s.data)
  result.add('\n')
  result.add(' '.repeat(s.pos) & "^ (" & $s.pos & ')')

func readChar(s: var ParseStream): R[char] =
  if s.isAtEnd:
    result = '\0'.ok
  else:
    result = s.data[s.pos].ok
    inc s.pos

# parsing #

template Parser(T: untyped): untyped =
  (proc (s: var ParseStream): R[T] {.nimcall, noSideEffect.})

const
  Nondigits* = Letters + {'-'}
  IdentChars* = Digits + Nondigits
  AlphanumericIdentChars* = Nondigits + IdentChars

func parse*[V](s: var ParseStream; parser: Parser(V)): R[V] =
  let
    startPos = s.pos
    parseResult = parser(s)
  if not parseResult.isOk:
    s.pos = startPos
  parseResult

func parseNothing*(s: var ParseStream): R[void] =
  result.ok

template maybe*[V](s: var ParseStream; parser: Parser(V)): R[V] =
  let parseResult = s.parse(parser)
  if parseResult.isOk:
    parseResult
  else:
    R[V].ok(V.default)

# repeat

template repeatImpl(resultType: typedesc; parser, separator: untyped; requireFirst: bool): untyped =
  var resultVal: resultType
  when requireFirst:
    # parse the first occurence
    resultVal.add(?s.parse(parser))
  # parse the rest
  while true:
    if not s.parse(separator).isOk:
      break
    let parseResult = s.parse(parser)
    if not parseResult.isOk:
      break
    else:
      resultVal.add(parseResult.value)
  resultVal.ok

func repeat*[V, S](s: var ParseStream; parser: Parser(V); separator: Parser(S)): R[seq[V]] =
  repeatImpl(seq[V], parser, separator, requireFirst = true)

func repeat*[V](s: var ParseStream; parser: Parser(V)): R[seq[V]] =
  repeatImpl(seq[V], parser, parseNothing, requireFirst = true)

func many*[V](s: var ParseStream; parser: Parser(V)): R[seq[V]] =
  repeatImpl(seq[V], parser, parseNothing, requireFirst = false)

func oneOf*[V](s: var ParseStream; parsers: varargs[Parser(V)]): R[V] =
  for parser in parsers:
    let parseResult = s.parse(parser)
    if parseResult.isOk:
      return parseResult
  (typeof result).err(s.pos)

# char

func parseChar*[charSet: static set[char]](s: var ParseStream): R[char] =
  let c = ?s.readChar()
  if c in charSet:
    result.ok(c)
  else:
    result.err(s.pos)

func parseStringOf*[charSet: static set[char]](s: var ParseStream): R[string] =
  repeatImpl(string, parseChar[charSet], parseNothing, requireFirst = true)

func parseString*[str: static string](s: var ParseStream): R[string] =
  var
    c: char
    i = 0
  while i < str.len and (c = ?s.readChar(); true):
    if c == str[i]:
      inc i
    else:
      break
  if i == str.len:
    result.ok(str)
  else:
    result.err(s.pos)

# ident

func parseAlphanumericIdent*(s: var ParseStream): R[string] =
  let resultVal = ?parseStringOf[AlphanumericIdentChars](s)
  if resultVal.contains(Nondigits):
    resultVal.ok
  else:
    (typeof result).err(s.pos)

func parseNumericIdent*(s: var ParseStream): R[string] =
  let resultVal = ?parseStringOf[Digits](s)
  if resultVal.len == 0 or (resultVal.len > 1 and resultVal[0] == '0'):
    (typeof result).err(s.pos)
  else:
    resultVal.ok

# core

func parseCore*(s: var ParseStream): R[array[3, int]] =
  let resultVal = ?s.repeat(parseNumericIdent, parseChar[{'.'}])
  if resultVal.len == 3:
    [
      resultVal[0].parseInt,
      resultVal[1].parseInt,
      resultVal[2].parseInt
    ].ok
  else:
    (typeof result).err(s.pos)

func parseCoreCoerce*(s: var ParseStream): R[tuple[core: array[3, int]; leftovers: string]] =
  ## Leniently parse the core.
  ## Cores with fewer than three numbers are right-padded with zeros.
  ## Cores with more than three numbers have their additional parts joined by '.' and returned as `leftovers`.
  var
    core = ?s.repeat(parseNumericIdent, parseChar[{'.'}])
    leftovers = ""
  if core.len < 3:
    for _ in 0 ..< 3 - core.len:
      core.add("0")
  elif core.len > 3:
    let leftoverParts = core[3..^1]
    core.setLen(3)
    leftovers = leftoverParts.join(".")
  ([
    core[0].parseInt,
    core[1].parseInt,
    core[2].parseInt,
  ], leftovers).ok

# prerelease

func parsePrereleaseIdent*(s: var ParseStream): R[string] =
  s.oneOf(parseAlphanumericIdent, parseNumericIdent)

func parsePrerelease*(s: var ParseStream): R[seq[string]] =
  discard ?s.parse(parseChar[{'-'}])
  s.repeat(parsePrereleaseIdent, parseChar[{'.'}])

# build

func parseBuild*(s: var ParseStream): R[seq[string]] =
  discard ?s.parse(parseChar[{'+'}])
  s.repeat(parseStringOf[AlphanumericIdentChars], parseChar[{'.'}])

# semver

func parseSemverInternal*(s: var ParseStream): R[Semver] =
  let
    core = ?parseCore(s)
    prerelease = ?s.maybe(parsePrerelease)
    build = ?s.maybe(parseBuild)
  Semver.init(core[0], core[1], core[2], prerelease, build).ok

func parseSemverCoerceInternal*(s: var ParseStream): R[Semver] =
  let
    (core, leftovers) = ?parseCoreCoerce(s)
    prerelease = ?s.maybe(parsePrerelease)
    buildPrefix =
      if leftovers != "":
        @[leftovers]
      else:
        @[]
    build = buildPrefix & ?s.maybe(parseBuild)
  Semver.init(core[0], core[1], core[2], prerelease, build).ok

func parseSemver*(s: var ParseStream; coerce: static[bool] = false): R[Semver] =
  let sv =
    when coerce:
      ?s.parse(parseSemverCoerceInternal)
    else:
      ?s.parse(parseSemverInternal)
  if s.isAtEnd:
    sv.ok
  else:
    (typeof result).err(s.pos)
