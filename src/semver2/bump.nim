import ./types

func bumpMajor*(sv: SemVer): SemVer =
  initSemVer(sv.major + 1)

func bumpMinor*(sv: SemVer): SemVer =
  initSemVer(sv.major, sv.minor + 1)

func bumpPatch*(sv: SemVer): SemVer =
  initSemVer(sv.major, sv.minor, sv.patch + 1)

# TODO: bumpPrerelease, bumpBuild
