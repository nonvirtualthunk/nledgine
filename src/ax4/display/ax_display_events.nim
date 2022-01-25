import hex
import engines/event_types
import worlds
import options
import engines/key_codes
import glm

type
   HexMouseEnter* = ref object of InputEvent
      hex* : AxialVec
      buttonDown*: bool
   HexMouseExit* = ref object of InputEvent
      hex* : AxialVec
      buttonDown*: bool
   HexMousePress* = ref object of InputEvent
      hex* : AxialVec
      button* : MouseButton
      position* : Vec2f
   HexMouseRelease* = ref object of InputEvent
      hex*: AxialVec
      button* : MouseButton
      position* : Vec2f
   HexMouseMove* = ref object of InputEvent
      hex*: AxialVec
      buttonDown*: bool
      position*: Vec2f
   CharacterSelect* = ref object of Event
      character* : Entity