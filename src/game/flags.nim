import tables
import worlds
import sugar
import config
import library
import resources
import options


type
   Flags* = object
      flags*: Table[Taxon, int]

   FlagInfo* = object
      mechanicalDescription*: string
      description*: string
      vagueDescription*: string
      minValue*: Option[int]
      maxValue*: Option[int]
      hidden*: bool


defineReflection(Flags)

proc readFromConfig*(cv: ConfigValue, v: var FlagInfo) =
   readFromConfigByField(cv, FlagInfo, v)
   if cv["limitToZero"].asBool(orElse = false):
      v.minValue = some(0)

defineSimpleLibrary[FlagInfo]("ax4/game/flags.sml", "Flags")