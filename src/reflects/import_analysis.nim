import sets
import strutils
import io

# UNFINISHED
proc analyzeImports(file: string, seen : HashSet[string]) =
  seen.incl(file)
  for line in readLines(file):
    if line.startsWith("import "):
      let nextImport = line[7..^1]
      analyzeImports(nextImport, seen)



