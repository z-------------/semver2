from std/strutils import join

type
  SemVer* = object
    major*: Natural
    minor*: Natural
    patch*: Natural
    prerelease*: seq[string]
    build*: seq[string]

func initSemVer*(major: int; minor, patch = 0; prerelease, build = newSeq[string]()): SemVer =
  SemVer(
    major: major,
    minor: minor,
    patch: patch,
    prerelease: prerelease,
    build: build
  )

func `$`*(sv: SemVer): string =
  result = $sv.major & '.' & $sv.minor & '.' & $sv.patch
  if sv.prerelease.len > 0:
    result.add('-' & sv.prerelease.join("."))
  if sv.build.len > 0:
    result.add('+' & sv.build.join("."))
