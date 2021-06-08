BodyParts {
  Hand {
    uses: [Manipulate]
  }
  Foot {
    uses: [Move]
  }
  Leg {

  }
  Arm {

  }

  RightHand {
    from: RightArm
    isA: Hand
  }
  RightArm {
    from: Torso
    isA: Arm
  }
  LeftHand {
    from: LeftArm
    isA: Hand
  }
  LeftArm {
    from: Torso
    isA: Arm
  }
  RightFoot {
    from: RightLeg
    isA: Foot
  }
  RightLeg {
    from: Torso
    isA: Leg
  }
  LeftFoot {
    from: LeftLeg
    isA: Foot
  }
  LeftLeg {
    from: Torso
    isA: Leg
  }
  Torso {

  }
  Head {
    from: Neck
  }
  Neck {
    from: Torso
  }
}