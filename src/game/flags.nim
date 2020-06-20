import tables
import worlds
import sugar
import config
import library
import resources


type
    Flags* = object
      flags* : Table[Taxon, int]


    FlagEquivalency* = enum
        Positive
        Negative
        One
        NegativeOne



    FlagInfo* = object
        description* : string
        vagueDescription* : string
        minValue* : int
        maxValue* : int
        hidden* : bool


defineReflection(Flags)

defineBasicReadFromConfig(FlagInfo)

defineSimpleLibrary[FlagInfo]("ax4/game/flags.sml", "Flags")