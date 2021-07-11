import entities
import events
import survival_core
import worlds
import glm
import game/randomness
import game/library
import tables
import algorithm
import sequtils
import worlds/taxonomy
import tiles
import core
import sets
import prelude
import worlds/taxonomy
import worlds/identity
import tables
import game/flags

const MaxGatherTickIncrement = Ticks(100)
const CraftingRange = 2

type PlantCreationParameters* = object
  # optionally specified growth stage to create at, defaults to a random stage distributed evenly across total age
  growthStage*: Option[Taxon]





# /+===================================================+\
# ||               Predefinitions                      ||
# \+===================================================+/
proc destroySurvivalEntity*(world: LiveWorld, ent: Entity, bypassDestructiveCreation: bool = false)




proc player*(world: LiveWorld) : Entity =
  for ent in world.entitiesWithData(Player):
    return ent
  SentinelEntity



proc debugIdentifier*(world: LiveWorld, entity: Entity) : string =
  if entity.hasData(Identity):
    let ID = entity[Identity]
    if ID.name.isSome:
      ID.kind.displayName & ":" & ID.name.get & "(" & $entity.id & ")"
    else:
      ID.kind.displayName & "(" & $entity.id & ")"
  else:
    "Entity(" & $entity.id & ")"

proc distance(world: LiveWorld, a,b: Entity): float =
  if a.hasData(Physical) and b.hasData(Physical):
    distance(a[Physical].position, b[Physical].position)
  else:
    warn &"Trying to compute distance between entities when not both are physical ({debugIdentifier(world, a)}, {debugIdentifier(world, b)})"
    100000.0

proc createResourcesFromYields*(world: LiveWorld, yields: seq[ResourceYield], source: Taxon) : seq[GatherableResource] =
  withWorld(world):
    var rand = randomizer(world, 19)
    for rsrcYield in yields:
      let gatherableRsrc = GatherableResource(
        resource: rsrcYield.resource,
        source: source,
        quantity: reduceable(rsrcYield.amountRange.rollInt(rand).int16)
      )
      result.add(gatherableRsrc)

proc createGatherableDataFromYields*(world: LiveWorld, ent: Entity, yields: seq[ResourceYield], source: Taxon) =
  withWorld(world):
    if not ent.hasData(Gatherable):
      ent.attachData(Gatherable())
    ent.data(Gatherable).resources.add(createResourcesFromYields(world, yields, source))


proc reduceDurability*(world: LiveWorld, ent: Entity, reduceBy: int) =
  if ent.hasData(Item):
    let evt = DurabilityReducedEvent(entity: ent, reducedBy: reduceBy, newDurability: max(0, ent[Item].durability.currentValue - reduceBy))
    world.eventStmts(evt):
      let item = ent[Item]
      item.durability.reduceBy(reduceBy)
      if item.durability.currentValue <= 0:
        destroySurvivalEntity(world, ent)
  else:
    info &"reduceDurability() called on non-item: {ent}"



proc createPlant*(world: LiveWorld, region: Entity, kind: Taxon, position: Vec3i, params: PlantCreationParameters = PlantCreationParameters()): Entity {.discardable.} =
  result = world.createEntity()
  world.eventStmts(PlantCreatedEvent(entity: result, plantKind: kind, position: position)):
    var rand = randomizer(world, 92)
    let plantInfo = library(PlantKind)[kind]

    var age: Ticks
    let stage = if params.growthStage.isSome:
      let s = params.growthStage.get
      age = plantInfo.growthStages[s].startAge
      s
    else:
      age = Ticks(rand.nextInt(plantInfo.lifespan.int))
      var chosenStage: Taxon
      for (stage, stageInfo) in toSeq(plantInfo.growthStages.pairs).sortedByIt(it[1].startAge.int):
        if stageInfo.startAge <= age:
          chosenStage = stage
      chosenStage


    let growthStageInfo = plantInfo.growthStages[stage]
    result.attachData(Plant(
      growthStage: stage
    ))
    result.attachData(Physical(
      images: growthStageInfo.images,
      position: position,
      createdAt: world[TimeData].currentTime - age,
      health: vital(plantInfo.health.rollInt(rand)).withRecoveryTime(plantInfo.healthRecoveryTime),
      region: region,
      occupiesTile: growthStageInfo.occupiesTile
    ))
    result.attachData(Identity(kind: kind))
    createGatherableDataFromYields(world, result, growthStageInfo.resources, kind)

    region[Region].entities.incl(result)
    region.tile(position.x,position.y,MainLayer).entities.add(result)


proc advanceWorld*(world: LiveWorld, byTicks: Ticks) =
  let time = world[TimeData]
  let startTime = time.currentTime
  for i in 0 ..< byTicks.int:
    world.eventStmts(WorldAdvancedEvent(tick: startTime + i)):
      time.currentTime = startTime + i


proc tileOn*(world: LiveWorld, entity: Entity): var Tile =
  withWorld(world):
    ifHasData(world, entity, Physical, phys):
      return tile(phys.region[Region], phys.position.x, phys.position.y, phys.position.z)

    err "tileOn(...) called with entity that was not on a specific tile, returning sentinel"
    let regionEnt = toSeq(world.entitiesWithData(Region))[0]
    tile(regionEnt, 0, 0, 0)

proc tileMoveTime*(tile: Tile) : Ticks =
  let tileLib = library(TileKind)
  for floorLayer in tile.floorLayers:
    let tileInfo = tileLib[floorLayer.tileKind]
    result += tileInfo.moveCost

proc removeItemFromGroundInternal*(world: LiveWorld, item: Entity) =
  if item.hasData(Physical):
    tileOn(world, item).entities = tileOn(world, item).entities.withoutValue(item)

proc primaryDirectionFrom*(a,b : Vec2i) : Direction =
  if a == b:
    Direction.Center
  else:
    let dx = b.x - a.x
    let dy = b.y - a.y
    if abs(dx) > abs(dy):
      if dx > 0:
        Direction.Right
      else:
        Direction.Left
    else:
      if dy > 0:
        Direction.Up
      else:
        Direction.Down

proc moveEntity*(world: LiveWorld, creature: Entity, toPos: Vec3i) =
  withWorld(world):
    if creature.hasData(Physical):
      let phys = creature.data(Physical)
      let fromPos = phys.position
      let toTile = phys.region.tile(toPos.x, toPos.y, toPos.z)

      if creature.hasData(Creature):
        let moveTime =
          creature[Creature].baseMoveTime +
          tileMoveTime(toTile)

        world.eventStmts(CreatureMovedEvent(entity: creature, region: phys.region, fromPosition: fromPos, toPosition: toPos)):
          creature[Physical].position = toPos
          creature[Physical].facing = primaryDirectionFrom(fromPos.xy, toPos.xy)
          advanceWorld(world, moveTime)
    else:
      warn "Cannot move entity without physical data"

proc moveEntityDelta*(world: LiveWorld, creature: Entity, delta: Vec3i) =
  if creature.hasData(Physical):
    moveEntity(world, creature, creature[Physical].position + delta)


proc createItem*(world: LiveWorld, region: Entity, itemKind: Taxon) : Entity =
  let lib = library(ItemKind)
  let ik = lib[itemKind]

  var rand = randomizer(world)

  let ent = world.createEntity()
  world.eventStmts(ItemCreatedEvent(entity: ent, itemKind: itemKind)):
    ent.attachData(Item(
      durability : reduceable(ik.durability.rollInt(rand)),
      decay: reduceable(ik.decay),
      breaksInto: ik.breaksInto,
      decaysInto: ik.decaysInto,
      actions: ik.actions
    ))

    ifPresent(ik.food):
      ent.attachData(Food(
        hunger: it.hunger.rollInt(rand).int32,
        stamina: it.stamina.rollInt(rand).int32,
        hydration: it.hydration.rollInt(rand).int32,
        sanity: it.sanity.rollInt(rand).int32,
        health: it.health.rollInt(rand).int32
      ))

    if ik.fuel > Ticks(0):
      ent.attachData(Fuel(
        fuel: ik.fuel,
        maxFuel: ik.fuel
      ))

    ifPresent(ik.light):
      ent.attachData(it)

    ifPresent(ik.fire):
      ent.attachData(it)

    ent.attachData(Physical(
      region: region,
      occupiesTile: ik.occupiesTile,
      weight: ik.weight.rollInt(rand).int32,
      images: ik.images,
      health: vital(ik.health.rollInt(rand)),
      createdAt: world[TimeData].currentTime
    ))

    ent.attachData(Flags(
      flags: ik.flags
    ))


    ent.attachData(Identity(kind: itemKind))

  ent



proc removeItemFromInventoryInternal(world: LiveWorld, item: Entity) =
  if item.hasData(Item):
    let itemData = item[Item]
    ifPresent(itemData.heldBy):
      world.eventStmts(ItemRemovedFromInventoryEvent(entity: item, fromInventory: it)):
        it[Inventory].items.excl(item)
        itemData.heldBy = none(Entity)

proc placeItem*(world: LiveWorld, entity: Option[Entity], item: Entity, atPosition: Vec3i, capsuled: bool) : bool {.discardable.} =
  let region = regionFor(world, item)

  let curEnts = entitiesAt(region[Region], atPosition)
  for ent in curEnts:
    if ent[Physical].occupiesTile and not ent[Physical].capsuled:
      if entity.isSome:
        world.addFullEvent(CouldNotPlaceItemEvent(entity: entity.get, placedEntity: item, position: atPosition))
      return false

  world.eventStmts(ItemPlacedEvent(entity: entity, placedEntity: item, position: atPosition, capsuled: capsuled)):
    let phys = item[Physical]
    phys.position = atPosition
    phys.capsuled = capsuled
    tileOn(world, item).entities.add(item)

    removeItemFromInventoryInternal(world, item)

  true



proc moveItemToInventory*(world: LiveWorld, item: Entity, toInventory: Entity) =
  let phys = item[Physical]
  let itemData = item[Item]

  var fromInventory: Option[Entity] = itemData.heldBy

  world.eventStmts(ItemMovedToInventoryEvent(entity: item, fromInventory: fromInventory, toInventory: toInventory)):
    ifPresent(fromInventory):
      world.eventStmts(ItemRemovedFromInventoryEvent(entity: item, fromInventory: it)):
        it[Inventory].items.excl(item)
    if fromInventory.isNone:
      removeItemFromGroundInternal(world, item)
    # note, check weight limits beforehand
    toInventory[Inventory].items.incl(item)
    itemData.heldBy = some(toInventory)

## Returns true if the entity given can access the item given for the purposes of crafting
proc canAccessForCrafting*(world: LiveWorld, entity: Entity, item: Entity) : bool =
  # if we're holding the item, we can definitely access it
  if item.hasData(Item):
    if item[Item].heldBy.isSome:
      let heldBy = item[Item].heldBy.get
      if heldBy == entity:
        return true
      else:
        # if we can access its container we can access it
        return canAccessForCrafting(world, entity, heldBy)

  if item.hasData(Physical):
    if distance(world, entity, item) <= CraftingRange:
      return true

  false

proc recursivelyExpandInventoryIncludingSelf(world: LiveWorld, entity: Entity, into : var seq[Entity]) =
  if entity.hasData(Item):
    into.add(entity)

  if entity.hasData(Inventory):
    for item in entity[Inventory].items:
      recursivelyExpandInventoryIncludingSelf(world, item, into)

proc entitiesAccessibleForCrafting*(world: LiveWorld, actor: Entity): seq[Entity] =
  recursivelyExpandInventoryIncludingSelf(world, actor, result)

  for tile in tilesInRange(world, regionFor(world, actor), actor[Physical].position, CraftingRange):
    for entity in tile.entities:
      if entity != actor:
        recursivelyExpandInventoryIncludingSelf(world, entity, result)







proc resourceYieldFor*(world: LiveWorld, target: Target, rsrc: GatherableResource): ResourceYield =
  let allYields = if rsrc.source.isA(† Plant):
    if target.isEntityTarget:
      let pk = plantKind(rsrc.source)
      let stage = target.entity[Plant].growthStage
      pk.growthStages.getOrDefault(stage).resources
    else:
      warn &"Tried to get a plant based yield from a non-entity target {target}"
      @[]
  elif rsrc.source.isA(† Creature):
    if target.isEntityTarget:
      let ck = creatureKind(rsrc.source)
      if target.entity.hasData(Creature):
        ck.liveResources
      else:
        warn "resourceYieldFor(...) does not yet support corpses"
        @[]
    else:
      warn &"Tried to get a creature based yield from a non-entity target {target}"
      @[]
  elif rsrc.source.isA(† TileKind):
    let tk = tileKind(rsrc.source)
    tk.resources
  else:
    warn &"resourceYieldFor(...) called with unsupported resource source: {rsrc.source}"
    @[]

  for rYield in allYields:
    if rYield.resource == rsrc.resource:
      return rYield

  warn "resourceYieldFor(...) found no matching resource in source"

proc effectiveGatherLevelFor*(rYield: ResourceYield, actions: Table[Taxon, ActionUse]) : Option[(ActionUse, float)] =
  var bestMethod = (ActionUse(kind: † UnknownThing), 0.0)
  echo "Determining effective gather level for ", rYield, " | ", actions
  for rMethod in rYield.gatherMethods:
    for action in rMethod.actions:
      # todo: incorporate minimum tool level
      let possibleAct = actions.getOrDefault(action)
      let levelForAction = possibleAct.value
      let effLevel = levelForAction.float / rMethod.difficulty.float

      if bestMethod[1] < effLevel:
        bestMethod = (possibleAct, effLevel)

  if bestMethod[1] > 0.0:
    some(bestMethod)
  else:
    none((ActionUse,float))



proc isSurvivalEntityDestroyed*(world: LiveWorld, entity: Entity) : bool =
  ifHasData(entity, Physical, phys):
    return phys.region == SentinelEntity
  false

proc destroyTileLayer*(world: LiveWorld, region: Entity, tilePos: Vec3i, layerKind: TileLayerKind, index: int) =
  world.eventStmts(TileLayerDestroyedEvent(region: region, tilePosition: tilePos, layerKind: layerKind, layerIndex: index)):
    let t = tilePtr(region[Region], tilePos.x, tilePos.y, tilePos.z)
    case layerKind:
      of TileLayerKind.Wall: t.wallLayers.delete(index,index)
      of TileLayerKind.Ceiling: t.ceilingLayers.delete(index,index)
      of TileLayerKind.Floor: t.floorLayers.delete(index,index)

proc destroyTarget*(world: LiveWorld, target: Target) =
  case target.kind:
    of TargetKind.Entity:
      destroySurvivalEntity(world, target.entity)
    of TargetKind.TileLayer:
      destroyTileLayer(world, regionFor(world, target), target.tilePos, target.layer, target.index)
    else:
      err &"Trying to destroy invalid target {target}"
      discard


# Place an entity in the same location as an existing entity, either inside an inventory
# or on the ground, as appropriate
proc placeEntityWith*(world: LiveWorld, ent: Entity, with: Entity) =
  if with.hasData(Item) and with[Item].heldBy.isSome:
    if ent.hasData(Item):
      moveItemToInventory(world, ent, with[Item].heldBy.get)
    else:
      placeItem(world, none(Entity), ent, with[Item].heldBy.get[Physical].position, true)
  elif with.hasData(Physical):
    placeItem(world, none(Entity), ent, with[Physical].position, with[Physical].capsuled)
  else:
    warn &"Placing entity with another makes no sense if the other is non-physical: {debugIdentifier(world, ent)}, {debugIdentifier(world, with)}"




# Do damage to the health of the given entity, returns true if that entity was destroyed in the process
# Note that when an entity is destroyed its data is no longer accessible from the world
proc damageEntity*(world: LiveWorld, ent: Entity, damageAmount: int, reason: string) : bool =
  if ent.hasData(Physical):
    world.eventStmts(DamageTakenEvent(entity: ent, damageTaken: damageAmount, reason: reason)):
      let phys = ent[Physical]
      phys.health.reduceBy(damageAmount)
      if phys.health.currentValue <= 0:
        destroySurvivalEntity(world, ent)

    ent[Physical].region == SentinelEntity
  else:
    info &"damageEntity() called on non-physical entity: {debugIdentifier(world, ent)}"
    false



type GatherResult = object
  gatheredItems : seq[Entity]
  gatherRemaining : bool
  actionsUsed: seq[ActionUse]


# Perofrm the gathering of the target using the provided parameters, storing outputs in `resources` and recording the time taken in `ticks`
proc gatherFrom*(world: LiveWorld, target: Target, ticks: var Ticks, resources: var seq[GatherableResource], actions: Table[Taxon, ActionUse]): GatherResult =
  let region = regionFor(world, target)
  for rsrc in resources.mitems:
    if rsrc.quantity.currentValue > 0:
      let rYield = resourceYieldFor(world, target, rsrc)
      let bestMethod = effectiveGatherLevelFor(rYield, actions)
      bestMethod.ifPresent:
        let actionToUse = bestMethod.get()[0]
        if not result.actionsUsed.contains(actionToUse):
          result.actionsUsed.add(actionToUse)
          
        let progressPerTick = bestMethod.get()[1]
        let (ticksPerDelta, delta) = if progressPerTick < 0.99999:
          (floor(1.0 / progressPerTick + 0.0001).int, 1)
        else:
          if progressPerTick - floor(progressPerTick) > 0.2:
            warn &"Progress per tick at a non-integer: {progressPerTick}"
          (1, progressPerTick.int)

        if ticksPerDelta >= 1 and delta >= 1:
          while ticks < MaxGatherTickIncrement and rsrc.quantity.currentValue() > 0:
            ticks += ticksPerDelta
            rsrc.progress += delta
            if rsrc.progress > rYield.gatherTime:
              rsrc.quantity.reduceBy(1)
              rsrc.progress = Ticks16(0)
              result.gatheredItems.add(createItem(world, region, rsrc.resource))
          result.gatherRemaining = rsrc.quantity.currentValue() > 0
          if not result.gatherRemaining and rYield.destructive:
            for remainingRsrc in resources:
              let remainingYield = resourceYieldFor(world, target, remainingRsrc)
              if remainingYield.gatheredOnDestruction:
                for i in 0 ..< remainingRsrc.quantity.currentValue():
                  result.gatheredItems.add(createItem(world, region, remainingRsrc.resource))

            destroyTarget(world, target)
            break
        else:
          warn &"No ticks per delta or no delta: {ticksPerDelta}, {delta}"


proc interact*(world: LiveWorld, entity: Entity, target: Target, actions: Table[Taxon, ActionUse]) : bool {.discardable.} =
  var ticks = Ticks(0)

  let region = regionEnt(world, entity)

  var gr: GatherResult
  case target.kind:
    of TargetKind.Entity:
      if target.entity.hasData(Gatherable):
        let gatherable = target.entity[Gatherable]
        gr = gatherFrom(world, target, ticks, gatherable.resources, actions)
    of TargetKind.TileLayer:
      let tp = tilePtr(target.region[Region], target.tilePos)
      gr = gatherFrom(world, target, ticks, tp[].layers(target.layer)[target.index].resources, actions)
    of TargetKind.Tile:
      err &"Cannot simply ineract with a tile as a whole, must pick individual layer: {target}"

  if gr.actionsUsed.nonEmpty:
    result = true
    let fromEntity = case target.kind:
      of TargetKind.Entity: some(target.entity)
      else: none(Entity)
    world.eventStmts(GatheredEvent(entity: entity, items: gr.gatheredItems, actions: gr.actionsUsed, fromEntity: fromEntity, gatherRemaining: gr.gatherRemaining)):
      for item in gr.gatheredItems:
        moveItemToInventory(world, item, entity)
      for action in gr.actionsUsed:
        if action.source != entity:
          reduceDurability(world, action.source, 1)

  # if we're interacting with something pyhsical then turn to face it
  let targetPos = positionOf(world, target)
  if entity.hasData(Physical) and targetPos.isSome:
    entity[Physical].facing = primaryDirectionFrom(entity[Physical].position.xy, targetPos.get().xy)
  advanceWorld(world, ticks)





proc facedPosition*(world: LiveWorld, entity: Entity) : Vec3i =
  if entity.hasData(Physical):
    let phys = entity[Physical]
    phys.position + vector3iFor(phys.facing)
  else:
    warn &"facedPosition has no meaning for a non-physical entity"
    vec3i(0,0,0)

proc interact*(world: LiveWorld, entity: Entity, tools: seq[Entity], target: Target) : bool {.discardable.} =
  var actions: Table[Taxon, ActionUse]
  proc addPossibleAction(action: Taxon, value: int, source: Entity) =
    if actions.getOrDefault(action).value < value:
      actions[action] = ActionUse(kind: action, value: value, source: source)

  if tools.isEmpty:
    addPossibleAction(† Actions.Gather, 1, entity)

  for tool in tools:
    if tool.hasData(Item):
      for action, value in tool[Item].actions:
        addPossibleAction(action, value, tool)
    elif tool.hasData(Player):
      addPossibleAction(† Actions.Gather, 1, tool)

  interact(world, entity, target, actions)

proc interact*(world: LiveWorld, entity: Entity, tools: seq[Entity], targetPos: Vec3i) : bool {.discardable.} =
  for target in entitiesAt(entity[Physical].region[Region], targetPos):
    if interact(world, entity, tools, Target(kind: TargetKind.Entity, entity: target)):
      return true
    if target.hasData(Physical) and target[Physical].occupiesTile:
      return false

  let region = regionFor(world, entity)
  let tile = tile(region, targetPos.x, targetPos.y, targetPos.z)
  if tile.wallLayers.nonEmpty:
    if interact(world, entity, tools, Target(kind: TargetKind.TileLayer, layer: TileLayerKind.Wall, region: region, tilePos: targetPos, index: tile.wallLayers.len - 1)):
      return true
  if tile.floorLayers.nonEmpty:
    if interact(world, entity, tools, Target(kind: TargetKind.TileLayer, layer: TileLayerKind.Floor, region: region, tilePos: targetPos, index: tile.floorLayers.len - 1)):
      return true
  if tile.ceilingLayers.nonEmpty:
    if interact(world, entity, tools, Target(kind: TargetKind.TileLayer, layer: TileLayerKind.Ceiling, region: region, tilePos: targetPos, index: tile.ceilingLayers.len - 1)):
      return true


proc possibleActions*(world: LiveWorld, actor: Entity, target: Entity) : seq[Taxon] =
  result.add(† Actions.Place)
  if target.hasData(Food):
    result.add(† Actions.Eat)
  if target.hasData(Item):
    let item = target[Item]
    result.add(toSeq(item.actions.keys))



proc matchesRequirement*(world: LiveWorld, actor: Entity, req: RecipeRequirement, item: Entity): bool =
  # Assume true if there are no specifiers (implicitly ought to match everything) or if the operator is an AND (it will then fail if any specifier fails)
  if req.specifiers.isEmpty:
    true
  else:
    # Special case for disallowing items that are on fire, unless fire is explicitly allowed
    if item.hasData(Fire) and item[Fire].active:
      var fireOk = false
      for specifier in req.specifiers:
        if specifier == † Flags.Fire:
          fireOk = true
          break
      if not fireOk:
        return false

    for specifier in req.specifiers:
      let matchesSpecifier = if specifier.isA(† Flag):
        if item.hasData(Flags):
          let flagValue = item[Flags].flagValue(specifier)
          if req.minimumLevel >= 0:
            flagValue > 0 and flagValue >= req.minimumLevel
          else:
            flagValue <= 0
        else:
          # Negative value indicates that the flag must not be present
          if req.minimumLevel < 0:
            true
          else:
            false
      elif specifier.isA(† Action):
        item.hasData(Item) and item[Item].actions.getOrDefault(specifier) >= max(req.minimumLevel, 1)
      else:
        item.hasData(Identity) and item[Identity].kind.isA(specifier)

      case req.operator:
        of BooleanOperator.AND:
          if not matchesSpecifier: return false
        of BooleanOperator.OR:
          if matchesSpecifier: return true
        else:
          warn &"Only AND and OR operators supported for requirement analysis in recipes"

    if req.operator == BooleanOperator.AND:
      true
    else:
      false


func eachMatchedAtLeastOnce(matchesByItem: seq[set[int8]], usedItems: set[int8], remainingReqs : set[int8], numReqs: int) : bool =
  if remainingReqs == {}:
    true
  else:
    for ri in 0 ..< numReqs:
      if remainingReqs.contains(ri.int8):
        for ii in 0 ..< matchesByItem.len:
          # we haven't already used this item and it is a match for this requirement
          if not usedItems.contains(ii.int8) and matchesByItem[ii].contains(ri.int8):
            if eachMatchedAtLeastOnce(matchesByItem, usedItems + {ii.int8}, remainingReqs - {ri.int8}, numReqs):
              return true
    false



# Assumes that you have already checked that this matches the recipe template
proc matchesRecipe*(world: LiveWorld, actor: Entity, recipe: ref Recipe, ingredients: Table[string, RecipeInputChoice]) : bool =
  let recipeTemplate = recipeTemplateFor(recipe)
  for slotKey, requirements in recipe.ingredients:
    let choice = ingredients.getOrDefault(slotKey)
    # if this recipe specifies a requirement for this slot, but there are no items in it (i.e. an optional slot) then don't match
    if choice.items.isEmpty:
      return false

    # ensure that every item chosen matches the requirements
    let isDistinct = recipeTemplate.recipeSlots[slotKey].`distinct`
    if isDistinct:
      # in the case of distinct slots we want to make sure that each of the specified requirements
      # is matched by at least one of the items
      var requirementsMatchedByItem : seq[set[int8]]
      for itemIndex in 0 ..< choice.items.len:
        requirementsMatchedByItem.add({})
        for reqIndex in 0 ..< requirements.len:
          if matchesRequirement(world, actor, requirements[reqIndex], choice.items[itemIndex]):
            requirementsMatchedByItem[itemIndex].incl(reqIndex.int8)
      return eachMatchedAtLeastOnce(requirementsMatchedByItem, {}, {0.int8 .. (requirements.len.int8-1)}, requirements.len)
    else:
      for item in choice.items:
        for req in requirements:
          if not matchesRequirement(world, actor, req, item):
            return false


  true


proc matchesSlot*(world: LiveWorld, actor: Entity, slot: RecipeSlot, item: Entity) : bool =
  matchesRequirement(world, actor, slot.requirement, item)

proc matchesRecipeTemplate*(world: LiveWorld, actor: Entity, recipeTemplate: ref RecipeTemplate, ingredients: Table[string, RecipeInputChoice]) : bool =
  for slotKey, slot in recipeTemplate.recipeSlots:
    let choice = ingredients.getOrDefault(slotKey)
    # if this recipe template marks this as required but there is nothing chosen, fail
    if choice.items.isEmpty and not slot.optional:
      return false

    # ensure that every item chosen matches the requirements
    for item in choice.items:
      if not matchesSlot(world, actor, slot, item):
        return false

  true


proc recursivelyAddSpecializations(r: ref Recipe, set: var HashSet[Taxon]) =
  if r.specializationOf != UnknownThing:
    set.incl(r.specializationOf)
    recursivelyAddSpecializations(recipe(r.specializationOf), set)


proc matchingRecipes*(world: LiveWorld, actor: Entity, recipeTemplate: ref RecipeTemplate, ingredients: Table[string, RecipeInputChoice]) : seq[ref Recipe] =
  if matchesRecipeTemplate(world, actor, recipeTemplate, ingredients):
    # track all the general recipes that have a more specific version that matches so we can ignore the general case
    var generalRecipesWithSpecificMatch : HashSet[Taxon]
    var matchingRecipes : seq[ref Recipe]

    for recipe in recipesForTemplate(recipeTemplate):
      if matchesRecipe(world, actor, recipe, ingredients):
        matchingRecipes.add(recipe)
        recursivelyAddSpecializations(recipe, generalRecipesWithSpecificMatch)

    matchingRecipes.filterIt(not generalRecipesWithSpecificMatch.contains(it.taxon))
  else:
    @[]






# Returns true if there is any recipe for which the given item would be a valid match for the listed slot key
proc matchesAnyRecipeInSlot*(world: LiveWorld, actor: Entity, recipeTemplate: ref RecipeTemplate, slot: string, item: Entity): bool =
  if not recipeTemplate.recipeSlots.hasKey(slot):
    warn &"recipe template does not have slot it advertized? {slot}"
  if recipeTemplate.recipeSlots.hasKey(slot) and matchesSlot(world, actor, recipeTemplate.recipeSlots[slot], item):
    for recipe in recipesForTemplate(recipeTemplate):
      if not recipe.ingredients.hasKey(slot):
        return true
      else:
        if recipeTemplate.recipeSlots[slot].`distinct`:
          for req in recipe.ingredients[slot]:
            if matchesRequirement(world, actor, req, item):
              return true
        else:
          var matchesAll = true
          for req in recipe.ingredients[slot]:
            if not matchesRequirement(world, actor, req, item):
              matchesAll = false
          if matchesAll:
            return true
  false



# Hypothetical indicates that we want to create what item would be crafted as a result of these parameters for the purpose of display
# or decision making. So do not destroy any of the ingredients or make random choices if relevant
proc craftItem*(world: LiveWorld, actor: Entity, recipeTaxon: Taxon, ingredients: Table[string, RecipeInputChoice], hypothetical: bool): Option[seq[Entity]] =
  # hypothetical crafting should not be done in the current region, we don't actually want something showing up, this is being created in the ether
  let region = if not hypothetical:
    regionFor(world, actor)
  else:
    SentinelEntity

  let recipe = recipe(recipeTaxon)
  let recipeTemplate = recipeTemplate(recipe.recipeTemplate)
  if matchesRecipe(world, actor, recipe, ingredients):
    var results : seq[Entity]
    for output in recipe.outputs:
      for i in 0 ..< output.count:
        let createdItem = createItem(world, region, output.item)
        if not createdItem.hasData(Flags):
          createdItem.attachData(Flags())
        for flag,v in recipeTemplate.addFlags:
          createdItem[Flags].flags[flag] = v

        results.add(createdItem)

    # Apply all of the contributions that the ingredients make to the final object
    for k, ingredient in ingredients:
      let slot = recipeTemplate.recipeSlots[k]
      if slot.kind == RecipeSlotKind.Ingredient:
        let foodCon = recipe.foodContribution.get(recipeTemplate.foodContribution)
        let durCon = recipe.durabilityContribution.get(recipeTemplate.durabilityContribution)
        let decayCon = recipe.decayContribution.get(recipeTemplate.decayContribution)
        let weightCon = recipe.weightContribution.get(recipeTemplate.weightContribution)
        var flagCon = recipe.flagContribution
        for k,v in recipeTemplate.flagContribution:
          flagCon[k] = v

        for output in results:
          for ingredient in ingredient.items:
            if output.hasData(Food) and ingredient.hasData(Food):
              let outFood = output[Food]
              let inFood = ingredient[Food]
              outFood.hunger = applyContribution(foodCon, outFood.hunger, inFood.hunger)
              outFood.stamina = applyContribution(foodCon, outFood.stamina, inFood.stamina)
              outFood.hydration = applyContribution(foodCon, outFood.hydration, inFood.hydration)
              outFood.sanity = applyContribution(foodCon, outFood.sanity, inFood.sanity)
              outFood.health = applyContribution(foodCon, outFood.health, inFood.health)
            if output.hasData(Item) and ingredient.hasData(Item):
              output[Item].durability = applyContribution(durCon, output[Item].durability, ingredient[Item].durability)
            if output.hasData(Item) and ingredient.hasData(Item):
              output[Item].decay = applyContribution(decayCon, output[Item].decay, ingredient[Item].decay)
            if output.hasData(Physical) and ingredient.hasData(Physical):
              output[Physical].weight = applyContribution(weightCon, output[Physical].weight, ingredient[Physical].weight)
            if output.hasData(Flags) and ingredient.hasData(Flags):
              let outFlags = output[Flags]
              let inFlags = ingredient[Flags]
              for k,v in flagCon:
                outFlags.flags[k] = applyContribution(v, outFlags.flags.getOrDefault(k), inFlags.rawFlagValue(k))



      if not hypothetical:
        # Ingredients are consumed, tools are used (durability), and locations just... chill
        if slot.kind == RecipeSlotKind.Ingredient:
          for item in ingredient.items:
            destroySurvivalEntity(world, item, bypassDestructiveCreation = true)
        elif slot.kind == RecipeSlotKind.Tool:
          for item in ingredient.items:
            reduceDurability(world, item, 1)

    if not hypothetical:
      # Todo: modify by skill
      advanceWorld(world, recipe.duration)
    some(results)
  else:
    warn &"Generally, should not try to craft an item out of ingredients that cannot make that recipe: {recipeTaxon}"
    none(seq[Entity])



proc eat*(world: LiveWorld, actor: Entity, target: Entity) : bool {.discardable.} =
  if target.hasData(Food) and actor.hasData(Creature):
    let fd = target[Food]
    let cd = actor[Creature]
    let pd = actor[Physical]
    let hungerRecover = min(cd.hunger.currentlyReducedBy, fd.hunger)
    let staminaRecover = min(cd.stamina.currentlyReducedBy, fd.stamina)
    let hydrationRecover = min(cd.hydration.currentlyReducedBy, fd.hydration)
    let sanityRecover = min(cd.sanity.currentlyReducedBy, fd.sanity)
    let healthRecover = min(pd.health.currentlyReducedBy, fd.health)

    world.eventStmts(FoodEatenEvent(entity: actor, eaten: target, hungerRecovered: hungerRecover, staminaRecovered: staminaRecover, hydrationRecovered: hydrationRecover, sanityRecovered: sanityRecover, healthRecovered : healthRecover)):
      cd.hunger.recoverBy(fd.hunger)
      cd.stamina.recoverBy(fd.stamina)
      cd.hydration.recoverBy(fd.hydration)
      cd.sanity.recoverBy(fd.sanity)
      pd.health.recoverBy(fd.health)

      destroySurvivalEntity(world, target)

      advanceWorld(world, TicksPerShortAction.Ticks)
    true
  else:
    false


# If a target is supplied, will attempt to ignite that. If not, will attempt to ignite whatever is in front of the actor
proc ignite*(world: LiveWorld, actor: Entity, tool: Entity, targetSpecified: Option[Target]) =
  let region = regionFor(world, actor)
  let target: Target = if targetSpecified.isSome:
    targetSpecified.get
  else:
    let facedPos = facedPosition(world, actor)
    let entities = entitiesAt(world, actor[Physical].region, facedPos)
    if entities.nonEmpty:
      targetEntity(entities[^1])
    else:
      targetTile(region, facedPos)

  case target.kind:
    of TargetKind.Entity:
      let targetEnt = target.entity

      if targetEnt.hasData(Fire):
        let fire = targetEnt[Fire]
        if not fire.active:
          world.eventStmts(IgnitedEvent(actor: actor, target: target, tool: tool)):
            fire.active = true
        else:
          world.addFullEvent(FailedToIgniteEvent(actor: actor, target: target, tool: tool, reason: "already on fire"))
      elif flagValue(world, targetEnt, † Flags.Inflammable) > 0:
        if targetEnt.hasData(Item) and targetEnt.hasData(Fuel):
          world.eventStmts(IgnitedEvent(actor: actor, target: target, tool: tool)):
            targetEnt.attachData(Fire(
              active: true,
              fuelRemaining: targetEnt[Fuel].fuel + 1,
              durabilityLossTime: some((targetEnt[Fuel].maxFuel.int div targetEnt[Item].durability.maxValue).Ticks)
            ))
        else:
          warn &"Logic for setting a non-(item+fuel) that is inflammable (but without specific burning qualities) aflame is not fleshed out {debugIdentifier(world, targetEnt)}"
          world.eventStmts(IgnitedEvent(actor: actor, target: target, tool: tool)):
            targetEnt.attachData(Fire(
              active: true,
              fuelRemaining: 100.Ticks,
              healthLossTime: some(10.Ticks),
              durabilityLossTime: some(10.Ticks)
            ))
      else:
        world.addFullEvent(FailedToIgniteEvent(actor: actor, target: target, tool: tool, reason: "is not flammable"))
    else:
      world.addFullEvent(FailedToIgniteEvent(actor: actor, target: target, tool: tool, reason: "is not implemented yet"))

  advanceWorld(world, TicksPerMediumAction.Ticks)





proc destroySurvivalEntity*(world: LiveWorld, ent: Entity, bypassDestructiveCreation: bool = false) =
  world.eventStmts(EntityDestroyedEvent(entity: ent)):
    if ent.hasData(Physical):
      let phys = ent[Physical]
      if not phys.region.isSentinel: # this indicates an entity has already been destroyed
        if not bypassDestructiveCreation:
          if ent.hasData(Creature):
            ent[Creature].dead = true
            # TODO: Create corpse
          elif ent.hasData(Fire) and ent[Fire].active:
            let burnsInto = ent[Fire].burnsInto.get(† Items.Ash)
            let newItem = createItem(world, phys.region, burnsInto)
            placeEntityWith(world, newItem, ent)
          elif ent.hasData(Item):
            let item = ent[Item]
            if item.breaksInto.isSome:
              let newItem = createItem(world, phys.region, item.breaksInto.get)
              placeEntityWith(world, newItem, ent)

        removeItemFromGroundInternal(world, ent)
        removeItemFromInventoryInternal(world, ent)
        phys.region[Region].entities.excl(ent)
        phys.region = SentinelEntity
    else:
      warn &"No current means of destroying non-physical entity {debugIdentifier(world, ent)}"


when isMainModule:
  let lib = library(PlantKind)
  let oakTaxon = taxon("Plants", "OakTree")
  let oak = lib[oakTaxon]

  let world = createLiveWorld()

  let region = world.createEntity()

  withWorld(world):
    region.attachData(Region)
    world.attachData(RandomizationWorldData())
    for i in 0 ..< 10:
      let plantEnt = createPlant(world, region, oakTaxon, vec3i(0,0,0), PlantCreationParameters())

    let log = createItem(world, region, † Items.Log)
    let axe = createItem(world, region, † Items.StoneAxe)
    let carrot = createItem(world, region, † Items.CarrotRoot)

    let recipe = recipe(† Recipes.CarvePlank)
    let recipeTemplate = recipeTemplate(recipe.recipeTemplate)

    var ingredients : Table[string, RecipeInputChoice]
    ingredients["Ingredient"] = RecipeInputChoice(items: @[log])
    ingredients["Blade"] = RecipeInputChoice(items: @[axe])

    assert matchingRecipes(world, SentinelEntity, recipeTemplate, ingredients).contains(recipe)

    assert not matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Blade", carrot)
    assert matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Blade", axe)
    assert not matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Ingredient", axe)
    assert matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Ingredient", log)

    assert matchesRecipeTemplate(world, SentinelEntity, recipeTemplate, ingredients) and matchesRecipe(world, SentinelEntity, recipe, ingredients)

    var wrongIngredients : Table[string, RecipeInputChoice]
    wrongIngredients["Ingredient"] = RecipeInputChoice(items: @[carrot])
    wrongIngredients["Blade"] = RecipeInputChoice(items: @[axe])
    assert matchesRecipeTemplate(world, SentinelEntity, recipeTemplate, ingredients) and not matchesRecipe(world, SentinelEntity, recipe, wrongIngredients)

    var wrongTool : Table[string, RecipeInputChoice]
    wrongTool["Ingredient"] = RecipeInputChoice(items: @[log])
    wrongTool["Blade"] = RecipeInputChoice(items: @[carrot])
    assert not matchesRecipeTemplate(world, SentinelEntity, recipeTemplate, wrongTool)
