import engines/event_types
import strformat


type
  WorldInitializedEvent* = ref object of GameEvent



method toString*(evt: WorldInitializedEvent): string =
   return &"WorldInitializedEvent{$evt[]}"