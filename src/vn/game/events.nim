import engines/event_types
import strformat
import glm
import worlds
import entities
import options
import game/library


type
  GameTickEvent* = ref object of GameEvent
    tick*: int

  VoxelChangedEvent* = ref object of GameEvent
    region*: Entity
    position*: Vec3i
    oldValue*: Voxel
    newValue*: Voxel

  RecipeCompletedEvent* = ref object of GameEvent
    machine*: Entity
    recipe*: LibraryTaxon



eventToStr(GameTickEvent)