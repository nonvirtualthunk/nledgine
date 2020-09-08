import worlds
import tables
import config
import strutils
import options
import noto
import game/library

import ax4/game/ax_events
import ax4/game/effect_types
import worlds/taxonomy
import resources
import config/config_helpers
import ax4/game/cards
import graphics/image_extras

type
   Weapon* = object
      attacks*: OrderedTable[AttackKey, WeaponAttack]
      attackCardCount*: int
      weaponSkills: seq[Taxon]

   WeaponAttack* = object
      name*: string
      attack*: Attack

   Inventory* = object
      equipped*: seq[Entity]
      held*: seq[Entity]

   Item* = object
      heldBy*: Option[Entity]
      equippedBy*: Option[Entity]
      equipCards*: seq[Entity]

   ItemArchetype* = object
      identity*: ref Identity
      weaponData*: ref Weapon


   ItemEquippedEvent* = ref object of AxEvent
      item*: Entity

   ItemUnequippedEvent* = ref object of AxEvent
      item*: Entity

   ItemRemovedFromInventoryEvent* = ref object of AxEvent
      item*: Entity

   ItemPlacedInInventoryEvent* = ref object of AxEvent
      item*: Entity


proc readFromConfig*(cv: ConfigValue, v: var WeaponAttack) =
   cv.readInto(v.attack)
   cv["name"].readInto(v.name)

defineSimpleReadFromConfig(Weapon)
defineReflection(Weapon)
defineReflection(Inventory)
defineReflection(Item)


method toString*(evt: ItemEquippedEvent, view: WorldView): string =
   return &"ItemEquipped({$evt[]})"
method toString*(evt: ItemUnequippedEvent, view: WorldView): string =
   return &"ItemUnequipped({$evt[]})"
method toString*(evt: ItemRemovedFromInventoryEvent, view: WorldView): string =
   return &"ItemRemovedFromInventory({$evt[]})"
method toString*(evt: ItemPlacedInInventoryEvent, view: WorldView): string =
   return &"ItemPlacedInInventory({$evt[]})"


proc removeFromInventory*(world: World, inventory: Entity, item: Entity) =
   withWorld(world):
      world.eventStmts(ItemRemovedFromInventoryEvent(entity: inventory, item: item)):
         inventory.modify(Inventory.held.remove(item))
         item.modify(Item.heldBy.setTo(none(Entity)))

proc placeInInventory*(world: World, inventory: Entity, item: Entity) =
   withWorld(world):
      world.eventStmts(ItemPlacedInInventoryEvent(entity: inventory, item: item)):
         inventory.modify(Inventory.held.append(item))
         item.modify(Item.heldBy.setTo(some(inventory)))

proc equipItem*(world: World, character: Entity, item: Entity) =
   withWorld(world):
      if not character[Inventory].equipped.contains(item):
         world.eventStmts(ItemEquippedEvent(entity: character, item: item)):
            if item[Item].heldBy.isSome:
               removeFromInventory(world, item[Item].heldBy.get, item)

            character.modify(Inventory.equipped.append(item))
            item.modify(Item.equippedBy.setTo(some(character)))

            for card in item[Item].equipCards:
               addCard(world, character, card, DeckKind.Combat, CardLocation.Hand)



proc unequipItem*(world: World, character: Entity, item: Entity) =
   withWorld(world):
      if character[Inventory].equipped.contains(item):
         world.eventStmts(ItemUnequippedEvent(entity: character, item: item)):
            character.modify(Inventory.equipped.remove(item))
            item.modify(Item.equippedBy.setTo(none(Entity)))

            placeInInventory(world, character, item)

            for card in item[Item].equipCards:
               removeCard(world, character, card)
      else:
         warn &"Attempted to unequip item from inventory that did not contain it"

proc equippedItems*(view: WorldView, character: Entity): seq[Entity] =
   withView(view):
      character[Inventory].equipped

defineLibrary[ItemArchetype]:
   var lib = new Library[ItemArchetype]
   lib.defaultNamespace = "items"

   let confs = @["weapons.sml"]
   for confPath in confs:
      let conf = resources.config("ax4/game/" & confPath)
      for k, v in conf["Items"]:
         let itemTaxon = taxon("items", k)
         var identity = readInto(v, Identity)
         identity.kind = itemTaxon
         let arch = ItemArchetype(
            identity: new Identity,
            weaponData: new Weapon
         )
         arch.identity[] = identity

         if itemTaxon.isA(taxon("items", "weapon")):
            readInto(v, arch.weaponData[])

         lib[itemTaxon] = arch

   lib

proc createItem*(world: World, taxon: Taxon): Entity =
   withWorld(world):
      let lib = library(ItemArchetype)

      let arch = lib[taxon]

      let ent = world.createEntity()
      var cards: seq[Entity]
      if arch.weaponData != nil:
         ent.attachData(arch.weaponData[])
         for i in 0 ..< arch.weaponData.attackCardCount:
            let card = world.createEntity()
            var cardData: Card
            cardData.image = imageLike("ax4/images/card_images/slash.png")

            for key, attack in arch.weaponData.attacks:
               cardData.cardEffectGroups.add(EffectGroup(
                  name: some(attack.name),
                  effects: @[SelectableEffects(
                     effects: @[GameEffect(
                        kind: GameEffectKind.Attack,
                        attackSelector: FromWeapon(ent, key)
                  )]
               )]))

            for weaponSkill in arch.weaponData.weaponSkills:
               cardData.xp[weaponSkill] = 1

            card.attachData(cardData)
            card.attachData(Identity(name: some("strike"), kind: taxon("card types", "AttackCard")))

            cards.add(card)
      ent.attachData(Item(equipCards: cards))
      ent
