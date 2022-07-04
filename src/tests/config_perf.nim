import resources
import prelude
import noto

when isMainModule:
  let startTime = relTime()
  let confA = config("survival/game/creatures.sml")
  let confB = config("survival/game/items.sml")
  let confC = config("survival/game/recipes.sml")
  let confD = config("survival/widgets/EquipmentSlotUI.sml")
  let confE = config("survival/widgets/ActionMenu.sml")
  let endTime = relTime()
  info &"Duration: {endTime - startTime}"
