import tables
import worlds
import sugar
import engines/event_types



type
    EventCondition* = (Event) -> bool

    FlagBehaviorKind = enum
        Delta
        Reset
        Divide
        Multiply

    FlagBehavior* = object
        condition : EventCondition
        case kind : FlagBehaviorKind
        of Delta : 
            delta : int
        of Reset : 
            discard
        of Divide :
            divisor : int
        of Multiply :
            multiplier : int

    FlagEquivalency* = enum
        Positive
        Negative
        One
        NegativeOne



    FlagInfo* = object
        flag* : Taxon
        description* : string
        minValue* : int
        maxValue* : int
        behaviors* : seq[FlagBehavior]
        hidden* : bool
