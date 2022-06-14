BodyParts {
  Hand {
    capabilities: [Manipulate]
    size: 2
  }
  Foot {
    capabilities: [BodyCapabilities.Move]
    size: 2
  }
  Paw {
    capabilities: [BodyCapabilities.Move]
    size: 2
  }
  Leg {
    capabilities: [BodyCapabilities.Move]
    size: 10
  }
  Arm {
    size: 6
  }

  RightHand {
    attachedFrom: RightArm
    isA: Hand
  }
  RightArm {
    attachedFrom: Torso
    isA: Arm
  }
  LeftHand {
    attachedFrom: LeftArm
    isA: Hand
  }
  LeftArm {
    attachedFrom: Torso
    isA: Arm
  }
  RightFoot {
    attachedFrom: RightLeg
    isA: Foot
  }
  RightLeg {
    attachedFrom: Torso
    isA: Leg
  }
  LeftFoot {
    attachedFrom: LeftLeg
    isA: Foot
  }
  LeftLeg {
    attachedFrom: Torso
    isA: Leg
  }

  # Four footed animals

  LeftForeLeg {
    attachedFrom: Torso
    isA: Leg
  }
  LeftForePaw {
    attachedFrom: LeftForeLeg
    isA: Paw
  }
  RightForeLeg {
    attachedFrom: Torso
    isA: Leg
  }
  RightForePaw {
    attachedFrom: RightForeLeg
    isA: Paw
  }
  LeftHindLeg {
    attachedFrom: Torso
    isA: Leg
  }
  LeftHindPaw {
    attachedFrom: LeftHindLeg
    isA: Paw
  }
  RightHindLeg {
    attachedFrom: Torso
    isA: Leg
  }
  RightHindPaw {
    attachedFrom: RightHindPaw
    isA: Paw
  }
  
  # Spider anatomy
  
  LeftInsectLeg1 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  LeftInsectLeg2 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  LeftInsectLeg3 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  LeftInsectLeg4 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  RightInsectLeg1 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  RightInsectLeg2 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  RightInsectLeg3 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  RightInsectLeg4 {
    size: 2
    isA: Leg
    attachedFrom: Thorax
  }
  Thorax {
    size: 16
  }

  # General

  Torso {
    size: 15
  }
  Head {
    attachedFrom: BodyParts.Neck
    capabilities: Think
    size: 5
  }
  Neck {
    attachedFrom: Torso
    size: 3
  }
}