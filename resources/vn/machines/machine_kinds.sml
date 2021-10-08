Machines {

  Aetherscoop {
    placementRestrictions: [FacingOutside, FacingForward]
    fixedRecipe: ScoopAether
    image: "vn/machines/aetherscoop_1.png"
    size: [3,3,3]
    outputs: [{
      input: false
      direction: Back
      relativePosition: [0, 0, 0]
      size: [3,1]
    }]
    flags: {
      Aetherscoop: 1
    }
  }
}