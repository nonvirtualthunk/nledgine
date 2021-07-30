import survival_core
import game/randomness
import worlds
import game/library
import glm
import graphics/images
import core
import tables
import config
import resources
import sets
import sequtils
import patty
import arxregex
import prelude
import strutils
import game/shadowcasting
import graphics/color

const VisionResolution* = 2
const ShadowResolution* = 2
const LocalLightRadius* = 64
const LocalLightRadiusWorldResolution* = 64 div ShadowResolution

type
  TileLayerKind* {.pure.} = enum
    Wall
    Floor
    Ceiling

  TargetKind* {.pure.} = enum
    Entity
    Tile
    TileLayer

  Target* = object
    case kind*: TargetKind
    of TargetKind.Entity:
      entity*: Entity
    of TargetKind.Tile, TargetKind.TileLayer:
      region*: Entity
      tilePos*: Vec3i
      # doesn't mean anything for `Tile` but that's fine
      layer*: TileLayerKind
      index*: int

  ResourceGatherMethod* = object
    # what action type triggers this gather method
    actions*: seq[Taxon]
    # how difficult is it to successfully gather this way
    difficulty*: float
    # how good a tool is required to be able to gather at all
    minimumToolLevel*: int

  ResourceYield* = object
    # what resource is there
    resource*: Taxon
    # how much of it is present
    quantity*: Distribution[int]
    # how can it be gathered
    gatherMethods*: seq[ResourceGatherMethod]
    # base amount of time it takes to gather
    gatherTime*: Ticks
    # is the tile/entity destroyed when all resources are gathered
    destructive*: bool
    # is this resource automatically gathered when the overall entity is destroyed by gathering
    # i.e. automatically getting the seeds and leaves when you dig up a carrot
    gatheredOnDestruction*: bool
    # how long it takes to regenerate 1 of this resource (in ticks)
    regenerateTime*: Option[Ticks]

  Vital* = object
    # The maximum value and how much it has been reduced by currently
    value*: Reduceable[int]
    # The number of ticks between recovering a point of this stat
    recoveryTime*: Option[Ticks]
    # The number of ticks between losing a point of this stat
    lossTime*: Option[Ticks]
    # The last point at which this stat recovered/lost
    lastRecoveryOrLoss*: Ticks

  Direction* = enum
    Center
    Left
    Up
    Right
    Down

  DayNight* {.pure.} = enum
    Day
    Night

  Physical* = object
    # position in three dimensional space within the region, x/y/layer
    position*: Vec3i
    # what region this entity is in
    region*: Entity
    # indicates an object that is lying on the ground in a non-constructed just-sort-of-sitting-around state
    # need to think of a better term
    capsuled*: bool
    # whether or not this entity fully occupies the tile it is on, preventing movement (assuming it is not capsuled)
    occupiesTile*: bool
    # whether or not this entity moves of its own accord
    dynamic*: bool
    # whether this entity has been destroyed
    destroyed*: bool
    # general size/weight, how much space it takes up in an inventory and how hard it is to move
    weight*: int32
    # images to display this entity on the map
    images*: seq[ImageRef]
    # abstraction over how close to destruction the entity is, may be replaced with higher fidelity later
    health*: Vital
    # when this entity was created in game ticks, used to calculate its age
    # note: represents creation in world-time, not game-engine-time, so something may be created as
    # many years old at world gen
    createdAt*: Ticks
    # what cardinal direction this entity is facing
    facing*: Direction

  Creature* = object
    # how much energy the creature has for performing difficult actons
    stamina*: Vital
    # how much hydration/water the creature has
    hydration*: Vital
    # how much food the creature has remaining before it starts starving
    hunger*: Vital
    # how sane the creature is
    sanity*: Vital
    # how many ticks before losing a point of hunger
    hungerLossTime*: Option[Ticks]
    # whether or not the creature has died
    dead*: bool
    # raw physical strength, applies to physical attacks, carrying, pushing, etc
    strength*: int8
    # dexterity, quickness, nimbleness, applies to dodging, fine motor skills, etc
    dexterity*: int8
    # general hardiness and resistance to damage, illness, etc
    constitution*: int8
    # baseline movement time required to traverse a single tile with no obstacles
    baseMoveTime*: Ticks
    # what kind of creature this is, its archetype/species/what have you
    creatureKind*: Taxon
    # what items are equipped to what body parts
    equipment*: Table[Taxon, Entity]

  Player* = object
    quickSlots*: array[10, Entity]
    vision*: ref ShadowGrid[64]
    visionRange*: int

  Plant* = object
    # current stage of growth (budding, vegetative growth, flowering, etc)
    growthStage*: Taxon


  GatherableResource* = object
    # The actual resource that can be gathered
    resource*: Taxon
    # From what the availability of this resource is derived (i.e. PlantKind, CreatureKind)
    source*: Taxon
    # How much of the resource remains and its maximum possible
    quantity*: Reduceable[int16]
    # How many ticks worth of progress have been made on gathering one unit of this resource
    progress*: Ticks16

  Gatherable* = object
    # resources that can be gathered from this entity
    resources*: seq[GatherableResource]

  Food* = object
    hunger*: int32
    stamina*: int32
    hydration*: int32
    sanity*: int32
    health*: int32


  LightSource* = object
    # how many tiles out the light will travel if uninterrupted
    brightness*: int
    # shadows cast by this light source
    lightGrid*: ref ShadowGrid[LocalLightRadius]
    # color of the light (purely cosmetic)
    lightColor*: RGBA
    # whether this light source is only active when on fire (i.e. a torch)
    fireLightSource*: bool

  Fuel* = object
    # how many ticks of fuel this provides to a standard fire
    fuel*: Ticks
    # the maximum ticks of fuel this provides in the event that it is possible to partially consume
    maxFuel*: Ticks

  CreatureKind* = object
    health*: DiceExpression
    healthRecoveryTime*: Option[Ticks]
    stamina*: DiceExpression
    staminaRecoveryTime*: Option[Ticks]
    hydration*: DiceExpression
    hydrationLossTime*: Option[Ticks]
    strength*: DiceExpression
    dexterity*: DiceExpression
    constitution*: DiceExpression
    baseMoveTime*: Ticks
    weight*: DiceExpression
    images*: seq[ImageRef]
    # resources that can be gathered from the creature while it is alive
    liveResources*: seq[ResourceYield]
    # resources that can only be gathered from the creature's corpse
    deadResources*: seq[ResourceYield]

  PlantGrowthStageInfo* = object
    # images for this stage of growth
    images*: seq[ImageRef]
    # images to use when resources are available
    withResourceImages*: Table[Taxon, ImageRef]
    # the age in ticks at which the plant enters this stage
    startAge*: Ticks
    # the resources the plant yields at this stage
    resources*: seq[ResourceYield]
    # whether or not the plant at this stage fully occupies its tile
    occupiesTile*: bool

  PlantKind* = object
    health*: DiceExpression
    healthRecoveryTime*: Option[Ticks]
    # stages of growth this plant goes through
    growthStages*: OrderedTable[Taxon, PlantGrowthStageInfo]
    # total lifespan in ticks after which the plant will die of natural causes
    lifespan*: Ticks

  Item* = object
    # how much use this item has remaining before breaking
    durability*: Reduceable[int]
    # what this item breaks down into when it runs out of durability, if anything
    breaksInto*: Option[Taxon]

    # how long remains before this item decays
    decay*: Reduceable[Ticks]
    # what this item decays into, if anything
    decaysInto*: Option[Taxon]

    # what other entity is holding this one in its inventory, if any
    heldBy*: Option[Entity]
    # actions that this item can be used for
    actions*: Table[Taxon, int]


  Inventory* = object
    # the maximum amount of weight that can be stored in this inventory
    maximumWeight*: int32
    # the items currently stored in this entity
    items*: HashSet[Entity]

  FoodKind* = object
    hunger*: DiceExpression
    stamina*: DiceExpression
    hydration*: DiceExpression
    sanity*: DiceExpression
    health*: DiceExpression

  ItemKind* = object
    durability*: DiceExpression
    breaksInto*: Option[Taxon]
    decay*: Ticks
    decaysInto*: Option[Taxon]
    weight*: DiceExpression
    health*: DiceExpression
    images*: seq[ImageRef]
    occupiesTile*: bool
    flags*: Table[Taxon, int]
    fuel*: Ticks
    light*: Option[LightSource]
    food*: Option[FoodKind]
    fire*: Option[Fire]
    # Whether individual items of this kind are sufficiently interchangeable that they
    # can be "stacked" when displayed rather than showing each individually
    stackable*: bool
    actions*: Table[Taxon, int]


  ActionKind* = object
    kind*: Taxon
    presentVerb*: string

  RecipeRequirement* = object
    # One of the given taxons must be matched in order for something to fit this specifier (OR'd together, effectively)
    # The values are interpreted implicitly by the type of taxon, supplying an Action requires that the item be able to make
    # that action, supplying a Flag indicates that the item must have that flag value, etc
    # supplying no values implicitly indicates that anything will match this requirement
    specifiers*: seq[Taxon]
    operator*: BooleanOperator
    # Minimum level required (if any) to count
    minimumLevel*: int

  RecipeSlot* = object
    description*: string
    kind*: RecipeSlotKind
    # requirements that must be met for an item to go in this ingredient slot
    requirement*: RecipeRequirement
    # whether this slot must be filled for every recipe or if can be left out
    optional*: bool
    # how many items go into this slot
    count*: int
    # whether the items in this slot should be treated individually (ingredients in a stew) or collectively (bricks in a wall)
    # a distinct slot allows you to treat it as many slots with a common definition
    `distinct`*: bool

  ContributionKind* {.pure.} = enum
    Additive
    Max
    Min

  Contribution* = object
    case kind*: ContributionKind
    of ContributionKind.Additive:
      fraction*: float
    of ContributionKind.Max, ContributionKind.Min:
      discard

  RecipeSlotKind* {.pure.} = enum
    Ingredient
    Tool
    Location

  RecipeTemplate* = object
    taxon*: Taxon
    description*: string
    icon*: ImageRef
    selectedIcon*: ImageRef
    # Inputs (ingredients, tools, locations) that can be required by recipes that use this template
    # i.e. Cooking needs an ingredient to cook, cookware (tool) to cook with, and a fire (location) to cook over
    recipeSlots*: OrderedTable[string, RecipeSlot]
    # What proportion of the food content of ingredients is incorporated into the new output
    foodContribution*: Contribution
    # What proportion of the durability of the ingredients is incorporated into the new output
    durabilityContribution*: Contribution
    # What proportion of the decay (max and current) of the ingredients is incorporated into the new output
    decayContribution*: Contribution
    # What flags from the ingredients are incorporated into the new output
    flagContribution*: Table[Taxon, Contribution]
    # What weight from the ingredients are incorporated into the new output
    weightContribution*: Contribution
    # Flags that are added to every item created from this template
    addFlags*: Table[Taxon, int]

  RecipeOutput* = object
    # What item is produced
    item*: Taxon
    # How  many are produced
    amount*: Distribution[int]
    # TODO: should be able to set food/durability/decay/etc contributions on a per-output basis (i.e. carving a log into planks, bark, and twigs)

  RecipeInputChoice* = object
    items*: seq[Entity]

  Recipe* = object
    taxon*: Taxon
    name*: string
    icon*: Option[string]
    # what general recipe template this is based on
    recipeTemplate*: Taxon
    # what other recipe this recipe is a specialization of (i.e. steel axe is a specialization of axe)
    specializationOf*: Taxon
    # further specification in the ingredient requirements that make this recipe get made when matched
    ingredients*: Table[string, seq[RecipeRequirement]]
    # what items are created as a result of this recipe
    outputs*: seq[RecipeOutput]
    # what skill is used in performing this recipe
    skill*: Taxon
    # how difficult the recipe is to perform, affects failure chance, experience gain, speed, etc
    difficulty*: int
    # how long the recipe takes to make, assuming no modifications
    duration*: Ticks
    # TODO: split the concept of durability of an object from durability when crafting something (i.e. a platonic torch created from thin air
    # has 20 durability, one crafted from components has -3 durability relative to the sum of its parts, they represent different things)

    # Note: all contributions below override the recipe template if provided
    # What proportion of the food content of ingredients is incorporated into the new output
    foodContribution*: Option[Contribution]
    # What proportion of the durability of the ingredients is incorporated into the new output
    durabilityContribution*: Option[Contribution]
    # What proportion of the decay (max and current) of the ingredients is incorporated into the new output
    decayContribution*: Option[Contribution]
    # What flags from the ingredients are incorporated into the new output (keys provided override the template)
    flagContribution*: Table[Taxon, Contribution]
    # What weight from the ingredients are incorporated into the new output
    weightContribution*: Option[Contribution]


  ActionUse* = object
    # what action this is, i.e. Chop, Carve
    kind*: Taxon
    # the relative level of ability, with 0 being no ability at all, should generally be >= 1
    value*: int
    # from where this action comes, the player if it is innate, or a tool if it is not
    source*: Entity

  # Used to track items that are on fire. Includes bonfires, clothes that got to close to bonfires, and creatures thrown into bonfires
  Fire* = object
    # whether this fire is actively aflame or if this is simply something that _could_ be lit
    active*: bool
    # how many ticks of fuel remain at standard consumption rate of 1 tick / tick. In the case of things that are not "supposed" to
    # be on fire this represents the duration until the fire naturally goes out
    fuelRemaining*: Ticks
    # relative rate of fuel consumption, 1.0 being 1 tick per tick, 2.0 being double consumption speed. No value equates to 1.0
    fuelConsumptionRate*: Option[float]
    # how many ticks between durability loss to the entity that is aflame (optional, i.e. creatures on fire do not lose durability)
    durabilityLossTime*: Option[Ticks]
    # how many ticks between health loss to the entity that is aflame (optional, i.e. campfires are not "damaged" by fire)
    healthLossTime*: Option[Ticks]
    # what this can be fueled by (if not set then cannot be refueled, i.e. a stick cannot be "refueled" if it is half burned)
    fueledBy*: Option[Taxon]
    # images to use when ignited
    activeImages*: seq[ImageLike]
    # what this entity becomes when consumed by fire. If not specified the default will just be ash
    burnsInto*: Option[Taxon]
    # whether this entity is destroyed when its fuel is exhausted (i.e. a torch), treated the same as if it was destroyed by fire
    consumedWhenFuelExhausted*: bool



defineSimpleReadFromConfig(Fire)

proc readFromConfig*(cv: ConfigValue, gm: var Contribution) =
  if cv.isStr:
    case cv.asStr.toLowerAscii:
      of "min": gm = Contribution(kind: ContributionKind.Min)
      of "max": gm = Contribution(kind: ContributionKind.Max)
      else: err &"Unknown contribution string representation: {cv.asStr}"
  elif cv.isNumber:
    gm = Contribution(kind: ContributionKind.Additive, fraction: cv.asFloat)
  else:
    err &"Unknown representation of Contribution value: {cv}"

proc readFromConfig*(cv: ConfigValue, gm: var ResourceGatherMethod) =
  if cv.isArr:
    let arr = cv.asArr
    cv[0].readInto(gm.actions)
    cv[1].readInto(gm.difficulty)
    cv[2].readInto(gm.minimumToolLevel)
  elif cv.isStr:
    gm.actions = @[taxon("Actions", cv.asStr)]
    gm.difficulty = 1
  else:
    cv["action"].readInto(gm.actions)
    cv["actions"].readInto(gm.actions)
    cv["difficulty"].readInto(gm.difficulty)
    cv["minimumToolLevel"].readInto(gm.minimumToolLevel)

proc readFromConfig*(cv: ConfigValue, ry: var ResourceYield) =
  readFromConfigByField(cv, ResourceYield, ry)
  if cv["gatherMethod"].nonEmpty:
    ry.gatherMethods = @[cv["gatherMethod"].readInto(ResourceGatherMethod)]
  if ry.gatherTime == Ticks(0):
    ry.gatherTime = Ticks(TicksPerShortAction)


proc readFromConfig*(cv: ConfigValue, r: var RecipeOutput) =
  if cv.isStr:
    let sections = cv.asStr.split('|')
    let kind = sections[0]
    let t = if kind.contains(".") : findTaxon(kind) else: taxon("Items", kind)
    let outputDistribution = if sections.len > 1:
      asConf(sections[1].strip).readInto(Distribution[int])
    else:
      constantDistribution(1.int)

    if t != UnknownThing:
      r.item = t
      r.amount = outputDistribution
    else:
      warn &"Recipe output did not have a valid item type: {cv.asStr}"
  else:
    readFromConfigByField(cv, RecipeOutput, r)
    if r.amount.maxValue == 0:
      r.amount = constantDistribution(1)


const taxonPlusNumRe = "([a-zA-Z0-9.]+)\\s?([0-9]+)?".re
const excludeTaxonRe = "!\\s?([a-zA-Z0-9.]+)".re
proc parseTaxonPlusNumber*(str: string) : Option[(Taxon, int)] =
  matcher(str):
    extractMatches(taxonPlusNumRe, taxonExpr, numExpr):
      let t = findTaxon(taxonExpr)
      if t == UnknownThing:
        warn &"Recipe requirement looking for unknown taxon: {taxonExpr}"
      else:
        var num = 1
        if numExpr.len > 0:
          num = numExpr.parseInt
        return some((t, num))
    extractMatches(excludeTaxonRe, taxonExpr):
      let t = findTaxon(taxonExpr)
      if t == UnknownThing:
        warn &"Recipe requirement looking for unknown taxon: {taxonExpr}"
      else:
        return some((t, -1))
    warn &"Recipe requirement had invalid formatted string: {str}"
  none((Taxon,int))

proc readFromConfig*(cv: ConfigValue, r: var RecipeRequirement) =
  if cv.isStr:
    let tpn = parseTaxonPlusNumber(cv.asStr)
    if tpn.isSome:
      r.specifiers = @[tpn.get()[0]]
      r.minimumLevel = tpn.get()[1]
  elif cv.isArr:
    for v in cv.asArr:
      let tpn = parseTaxonPlusNumber(cv.asStr)
      if tpn.isSome:
        r.specifiers.add(tpn.get()[0])
        if r.minimumLevel != tpn.get()[1] and r.minimumLevel != 0:
          warn &"Multiple minimum levels specified for recipe. Specifier {tpn.get()[1]}, levels: {r.minimumLevel}, {tpn.get()[1]}"
        r.minimumLevel = tpn.get()[1]
  else:
    readFromConfigByField(cv, RecipeRequirement, r)

proc readFromConfig*(cv: ConfigValue, k : var RecipeSlotKind) =
  case cv.asStr.toLowerAscii:
    of "tool": k = RecipeSlotKind.Tool
    of "location": k = RecipeSlotKind.Location
    of "ingredient": k = RecipeSlotKind.Ingredient

defineSimpleReadFromConfig(RecipeSlot)

proc readFromConfig*(cv: ConfigValue, r: var RecipeTemplate) =
  readFromConfigByField(cv, RecipeTemplate, r)

  for k,slot in cv["ingredients"].readInto(OrderedTable[string,RecipeSlot]):
    r.recipeSlots[k] = slot
    r.recipeSlots[k].kind = RecipeSlotKind.Ingredient
  for k,slot in cv["tools"].readInto(OrderedTable[string,RecipeSlot]):
    r.recipeSlots[k] = slot
    r.recipeSlots[k].kind = RecipeSlotKind.Tool
  for k,slot in cv["locations"].readInto(OrderedTable[string,RecipeSlot]):
    r.recipeSlots[k] = slot
    r.recipeSlots[k].kind = RecipeSlotKind.Location

defineSimpleReadFromConfig(PlantGrowthStageInfo)
defineSimpleReadFromConfig(PlantKind)
defineSimpleReadFromConfig(FoodKind)
defineSimpleReadFromConfig(ActionKind)
defineSimpleReadFromConfig(CreatureKind)
defineSimpleReadFromConfig(Recipe)

proc readFromConfig*(cv: ConfigValue, ik: var LightSource) =
  cv["brightness"].readInto(ik.brightness)
  cv["lightColor"].readInto(ik.lightColor)
  cv["fireLightSource"].readInto(ik.fireLightSource)

proc readFromConfig*(cv: ConfigValue, ik: var ItemKind) =
  cv["durability"].readInto(ik.durability)
  cv["decay"].readInto(ik.decay)
  cv["weight"].readInto(ik.weight)
  cv["health"].readInto(ik.health)
  cv["image"].readInto(ik.images)
  cv["images"].readInto(ik.images)
  cv["occupiesTile"].readInto(ik.occupiesTile)
  cv["fuel"].readInto(ik.fuel)
  cv["food"].readInto(ik.food)
  cv["fire"].readInto(ik.fire)
  cv["light"].readInto(ik.light)
  cv["stackable"].readInto(ik.stackable)
  let flags = cv["flags"]
  if flags.isObj:
    for k,v in flags.fields:
      ik.flags[taxon("Flags", k)] = v.asInt

  let actions = cv["actions"]
  if actions.isObj:
    for k,v in actions.fields:
      ik.actions[taxon("Actions", k)] = v.asInt

defineReflection(Player)
defineReflection(Creature)
defineReflection(LightSource)
defineReflection(Gatherable)
defineReflection(Plant)
defineReflection(Physical)
defineReflection(Item)
defineReflection(Inventory)
defineReflection(Food)
defineReflection(Fuel)
defineReflection(Fire)


const DirectionVectors* = [vec2i(0,0), vec2i(-1,0), vec2i(0,1), vec2i(1,0), vec2i(0,-1)]
const DirectionVectors3f* = [vec3f(0,0,0), vec3f(-1,0,0), vec3f(0,1,0), vec3f(1,0,0), vec3f(0,-1,0)]
const DirectionVectors3i* = [vec3i(0,0,0), vec3i(-1,0,0), vec3i(0,1,0), vec3i(1,0,0), vec3i(0,-1,0)]

proc vectorFor*(d: Direction) : Vec2i = DirectionVectors[d.ord]
proc vector3fFor*(d: Direction) : Vec3f = DirectionVectors3f[d.ord]
proc vector3iFor*(d: Direction) : Vec3i = DirectionVectors3i[d.ord]

defineSimpleLibrary[PlantKind]("survival/game/plant_kinds.sml", "Plants")
defineSimpleLibrary[ItemKind]("survival/game/items.sml", "Items")
defineSimpleLibrary[ActionKind]("survival/game/actions.sml", "Actions")
defineSimpleLibrary[CreatureKind]("survival/game/creatures.sml", "Creatures")
defineSimpleLibrary[RecipeTemplate]("survival/game/recipe_templates.sml", "RecipeTemplates")
# defineSimpleLibrary[Recipe]("survival/game/recipes.sml", "Recipes")
defineLibrary[Recipe]:
  let namespace = "Recipes"
  var lib = new Library[Recipe]
  lib.defaultNamespace = namespace

  for confPath in @["survival/game/recipes.sml", "survival/game/items.sml"]:
    let confs = config(confPath)
    for k, v in confs["Recipes"].pairsOpt:
      let key = taxon("Recipes", k)
      var ri: ref Recipe = new Recipe
      ri.taxon = key

      readInto(v, ri[])
      lib[key] = ri
    for k, v in confs["Items"].pairsOpt:
      let itemKey = taxon("Items", k)
      if v.hasField("recipe"):
        let key = taxon("Recipes", k)
        var ri : ref Recipe = new Recipe
        ri.taxon = key

        readInto(v["recipe"], ri[])
        if ri.outputs.isEmpty:
          let amount = if v["recipe"]["amount"].isEmpty:
            constantDistribution(1)
          else:
            v["recipe"]["amount"].readInto(Distribution[int])
          ri.outputs.add(
            RecipeOutput(
              item: itemKey,
              amount: amount
            )
          )
        lib[key] = ri

  lib

proc plantKind*(kind: Taxon) : ref PlantKind = library(PlantKind)[kind]
proc itemKind*(kind: Taxon) : ref ItemKind = library(ItemKind)[kind]
proc actionKind*(kind: Taxon) : ref ActionKind = library(ActionKind)[kind]
proc creatureKind*(kind: Taxon) : ref CreatureKind = library(CreatureKind)[kind]
proc recipeTemplate*(kind: Taxon): ref RecipeTemplate = library(RecipeTemplate)[kind]
proc recipeTemplateFor*(recipe: ref Recipe): ref RecipeTemplate = recipeTemplate(recipe.recipeTemplate)
proc recipe*(kind: Taxon): ref Recipe = library(Recipe)[kind]




addTaxonomyLoader(TaxonomyLoader(
  loadTaxonsFrom: proc(cv: ConfigValue) : seq[ProtoTaxon] {.gcsafe.} =
      var r : seq[ProtoTaxon]
      for key, item in cv["Items"].pairsOpt:
        if item["recipe"].nonEmpty:
          r.add(ProtoTaxon(namespace: "Recipes", name: key, parents : @["Recipe"]))
      r
))


proc recipesForTemplate*(t: ref RecipeTemplate) : seq[ref Recipe] =
  for k,recipe in library(Recipe):
    if recipe.recipeTemplate == t.taxon:
      result.add(recipe)

proc vital*(maxV: int): Vital = Vital(value: reduceable(maxV))
proc withRecoveryTime*(v: Vital, t : Ticks): Vital =
  result = v
  result.recoveryTime = some(t)
proc withRecoveryTime*(v: Vital, t : Option[Ticks]): Vital =
  result = v
  result.recoveryTime = t
proc withLossTime*(v: Vital, t : Ticks): Vital =
  result = v
  result.lossTime = some(t)
proc withLossTime*(v: Vital, t : Option[Ticks]): Vital =
  result = v
  result.lossTime = t

proc allEquippedItems*(c: ref Creature) : seq[Entity] =
  toSeq(c.equipment.values)

proc currentValue*(v: Vital): int = v.value.currentValue
proc maxValue*(v: Vital): int = v.value.maxValue
proc recoverBy*(v: var Vital, i : int) =
  v.value.recoverBy(i)
proc reduceBy*(v: var Vital, i : int) =
  v.value.reduceBy(i)
proc recoverBy*(v: var Vital, i : int32) =
  v.value.recoverBy(i.int)
proc reduceBy*(v: var Vital, i : int32) =
  v.value.reduceBy(i.int)
proc currentlyReducedBy*(v: Vital): int =
  v.value.currentlyReducedBy


proc applyContribution*(con: Contribution, cur: int, arg: int) : int =
  case con.kind:
    of ContributionKind.Additive: cur + (arg.float * con.fraction).int
    of ContributionKind.Max: max(cur, arg)
    of ContributionKind.Min: min(cur, arg)

proc applyContribution*(con: Contribution, cur: int32, arg: int32) : int32 =
  case con.kind:
    of ContributionKind.Additive: cur + (arg.float * con.fraction).int32
    of ContributionKind.Max: max(cur, arg)
    of ContributionKind.Min: min(cur, arg)
    
proc applyContribution*(con: Contribution, cur: float, arg: float) : float =
  case con.kind:
    of ContributionKind.Additive: cur + (arg.float * con.fraction).float
    of ContributionKind.Max: max(cur, arg)
    of ContributionKind.Min: min(cur, arg)

proc applyContribution*(con: Contribution, cur: Ticks, arg: Ticks) : Ticks =
  case con.kind:
    of ContributionKind.Additive: cur + (arg.int.float * con.fraction).int.Ticks
    of ContributionKind.Max: max(cur.int, arg.int).Ticks
    of ContributionKind.Min: min(cur.int, arg.int).Ticks

proc applyContribution*[T](con: Contribution, cur: Reduceable[T], arg: Reduceable[T]) : Reduceable[T] =
  case con.kind:
    of ContributionKind.Additive: reduceable(applyContribution(con, cur.maxValue, arg.currentValue))
    of ContributionKind.Max: reduceable(max(cur.maxValue, arg.currentValue))
    of ContributionKind.Min: reduceable(min(cur.maxValue, arg.currentValue))

proc `==`*(a,b: Target): bool =
  if a.kind == b.kind:
    case a.kind:
      of TargetKind.Entity: a.entity == b.entity
      of TargetKind.TileLayer: a.tilePos == b.tilePos and a.region == b.region and a.layer == b.layer and a.index == b.index
      of TargetKind.Tile: a.tilePos == b.tilePos and a.region == b.region
  else:
    false

proc isEntityTarget*(target: Target) : bool =
  target.kind == TargetKind.Entity

proc isTileTarget*(target: Target) : bool =
  case target.kind:
    of TargetKind.Tile, TargetKind.TileLayer:
      true
    else:
      false

proc entityTarget*(entity: Entity): Target =
  Target(kind: TargetKind.Entity, entity: entity)

proc tileTarget*(region: Entity, tilePos: Vec3i): Target =
  Target(kind: TargetKind.Tile, region: region, tilePos: tilePos)


proc positionOf*(world: LiveWorld, target: Target): Option[Vec3i] =
  case target.kind:
    of TargetKind.Tile, TargetKind.TileLayer:
      some(target.tilePos)
    of TargetKind.Entity:
      if target.entity.hasData(Physical):
        some(target.entity[Physical].position)
      else:
        none(Vec3i)

proc regionEnt*(world: LiveWorld, entity: Entity) : Entity =
  entity[Physical].region

when isMainModule:
  let lib = library(ItemKind)
  let carrot = lib[† Items.RoastedCarrot]
  echo $carrot


