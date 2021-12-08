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
