import engines
import worlds
import arxmath
import entities
import game/library
import prelude
import events
import noto
import glm
import logic
import game/grids

type
  MachineComponent = ref object of LiveGameComponent
    

proc machineComponent*() : MachineComponent =
  result = new MachineComponent

method initialize(g: MachineComponent, world: LiveWorld) =
  g.name = "MachineComponent"

proc updateMachines(g: MachineComponent, world: LiveWorld, tick: int) =
  for region in world[Regions].regions:
    let reg = region[Region]
    for ent in world.entitiesWithData(Machine):
      let mach = ent[Machine]
      if mach.region != region: continue

      let mk = machineKind(mach.kind)
      if mach.activeRecipe.isSome:
        let recipe = recipeKind(mach.activeRecipe.get)
        if hasAllIngredients(mach, recipe):
          mach.progress += mk.speed
          if mach.progress >= recipe.duration:
            mach.progress = recipe.duration
            if mach.pendingOutputs.isEmpty:
              mach.progress = 0
              world.addEvent(RecipeCompletedEvent(machine: ent, recipe: mach.activeRecipe.get))
              for recipeOutput in recipe.outputs:
                for i in 0 ..< recipeOutput.quantity:
                  # todo: chance
                  mach.pendingOutputs.add(MachineIngredient(label: recipeOutput.label, objectKind: recipeOutput.objectKind))

      var indexesToRemove: seq[int]
      var mi = 0
      for machOutput in mach.pendingOutputs:
        var allPossibleOutputLocations : seq[Vec3i]
        for outputInterface in mk.outputs:
          if outputInterface.label == machOutput.label:
            allPossibleOutputLocations.add(targetPositions(mach, outputInterface))
        for i in 0 ..< allPossibleOutputLocations.len:
          let pos = allPossibleOutputLocations[(i + mach.outputIncrementor) mod allPossibleOutputLocations.len]
          if reg.objects[pos] == 0:
            reg.objects[pos] = machOutput.objectKind
            mach.outputIncrementor.inc
            indexesToRemove.add(mi)
            break
        mi.inc

      for ii in countdown(indexesToRemove.len-1, 0):
        mach.pendingOutputs.del(indexesToRemove[ii])





method onEvent(g: MachineComponent, world: LiveWorld, event: Event) =
  matcher(event):
    extract(GameTickEvent, tick):
      updateMachines(g, world, tick)