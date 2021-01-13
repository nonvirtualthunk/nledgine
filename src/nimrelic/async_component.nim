import engines
import graphics
import prelude
import reflect
import asyncdispatch

type
   AsyncComponent* = ref object of GraphicsComponent

method initialize(g: AsyncComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "AsyncComponent"


method update(g: AsyncComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   if hasPendingOperations():
      poll(0)
