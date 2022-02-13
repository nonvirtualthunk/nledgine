Encounters {
  SundarsLanding|Initial {
    text: "The journey through the Gate does not bear remembering. Simple, honest darkness would have been preferrable to the colors that lit that interminable passage. The way forward was clear and empty, but looking back nothing could be seen but a web of thorns, and each vine covered in watchful, waiting eyes. You did not look back again until you felt the warm air of a new world on your face."
    options: [{
      kind: Choice
      prompt: "Continue..."
      hidden: true
      requirement: [Qualities.Urchin, 1]
      next: SundarsLanding|Initial|Urchin
    }]
  }
  SundarsLanding|Initial|Urchin {
    text: "The better sorts have to be paid to take the crossing. They have something they're leaving behind. For you, all you left behind were bad memories, a certain amount of suspicion by the local magistrate, and a cautious respect among the lower folk of the back alleys of the capital. In exchange you've gained a new start in life and a Worrying Debt to someone on the other side who arranged your arrival."
    options: {
      kind: Choice
      prompt: "Continue..."
      next: [
        [Qualities.AWorryingDebt, 1]
        SundarsLanding|Main
      ]
    }
  }
  SundarsLanding|Main {
    text: "Sundar's Gate broods over the city that encircles it in widening rings, visible at its great height even from the outer edges of the city. Three great roads lead inward to feed it the products of conquest and cultivation. Spire wood, fiddler's glass, distressingly shaped but nourishing foodstuffs all make their way by cart, ox, and man to the Gate and through to feed the distant empire beyond. Around them and off a maze of smaller tributaries are a dizzing array of buildings all abuzz with a similarly dizzying array of people. Here is the bastion of civilization in the wild lands of the Crossroads."
    options: [{
      kind: Location
      prompt: "The Gate"
      text: "The Gate is clearly visible from most places, despite the best efforts of the inhabitants to put something between them and its disquieting bulk. You don't need to ask anyone for directions."
      next: SundarsLanding|TheGate
    },{
      kind: Location
      prompt: "The Inner Ring"
      text: "A furlong or so out from the Gate the first ring of buildings begins. The seats of those loyal servants of Her Eminence who have followed the call of duty beyond the confines of the world."
      next: SundarsLanding|TheInnerRing
    }]
  }
  SundarsLanding|TheGate {
    text: "The Gate brings the exiled and the opportunistic across the gulfs of space and time to this world. Anything can come through, but no living thing has ever made it back. A steady trickle of individuals make their way out looking haggard and worn. A much larger flow of goods empties continuously into the maw to feed the motherland beyond. You try to avoid looking too directly at the space between the basalt pillars, you'd rather not catch the eye of anything inside."
    options: [
      {
        kind: Choice
        requirements: [
          [Qualities.RecruitingAtTheGate,0]
          [Money, 10]
        ]
        prompt: "Recruit newcomers for your party"
        text: "The people stumbling out of the Gate have a tendency to be in need of a bit of coin, a steady source of meals, or both. Give the promise of those and you may be able to expand your corp of loyal followers."
        challenge: [Spirit,1]
        onSuccess: [{
          text: "You catch a pair of worryworn bondsmen as they get their bearings. Your tales of the wonders beyond the walls and hot meals every night prove more tempting than the hard labor contract that got them over. A quick hustle away from an approaching foreman and your party grows."
          effects: [
            [Money, -10],
            [Crew, 2]
            [Qualities.RecruitingAtTheGate,1]
          ]
        },{
          text: "A lone woman walks out looking unusually relieved for someone who has just made the passage. She is quickly amenable to your offer with particular appreciation for your \"no questions asked\" policy, though she negotiates an extra signing bonus, on principle."
          condition: [Occurrences.RecruitingAtTheGate|LoneWoman,0]
          effects: [
            [Money, -7]
            [Crew, 1]
            [Occurrences.RecruitingAtTheGate|LoneWoman,1]
            [Qualities.RecruitingAtTheGate,1]
          ]
        },{
          text: "You catch a trio of young men as they finish their bold and slightly inebrieted sprint through the darkness. The solidity of the coins you offer provides something to stave off the growing uncertainty in the wisdom of their decision."
          effects: [
            [Money, -10]
            [Crew, 3]
            [Qualities.RecruitingAtTheGate,1]
          ]
        },{
          text: "You approach a likely candidate: strong of frame, not too obviously possessing of superior prospects. But when he turns to you his eyes are wide and frantic and he grips your arm like a vice. He doesn't accept any coin but he also doesn't let go of your arm until you're well away from the Gate. He's not much for talking but proves a capable cook and is consequently popular among the crew."
          condition: [Occurrences.RecruitingAtTheGate|FranticCook,0]
          effects: [
            [Crew, 1]
            [Terror, 5]
            [Qualities.RecruitingAtTheGate,1]
            [Occurrences.RecruitingAtTheGate|FranticCook,1]
          ]
        },{
          text: "Criminals who aren't enough trouble to justify the noose but too much trouble to be let free often get offered the queen's forgiveness on the far side. Officially they're bound for laboring on one of Her Eminence's many projects but the foremen are none too scrupulous. A few coins now are easily spent and no one will miss an extra, sullen mouth to feed. The sullen mouths in question look hopeful at a change of fortune that doesn't involve slow death in the mines. You don't pick this moment to tell them about the many opportunities for slow death in the wilds."
          effects: [
            [Money, -10]
            [Crew, "2-3"]
            [Qualities.RecruitingAtTheGate,1]
          ]
        }]
      },{
        kind: Choice
        prompt: "Return to the city"
        next: SundarsLanding|Main
      }
    ]
  }

  SundarsLanding|TheInnerRing {
    text: "The buildings closest to the Gate were built early on, when the first expeditions crossed through. Generally the architects seem to have wanted to erect beacons of culture and civilization to enthrall an untamed world. The effect is slightly spoiled by the practical necessity for crenelations, spikes, and arrow slits. The defensive ditches have been transformed into decorative ponds, however, and the entire district is filled with the colors of flowering water plants. The calls from the floating stalls compete with the insistent requests of the waterfowl for the attention of passers by."
    options: [{
      kind: Choice
      prompt: "Purchase a roasted duck"
      text: "You fancy that the birds swimming nearest to the stall are eyeing you reproachfully as you approach, but the tall man at the grill is very enthusiastic about the freshness of his wares."
      requirements: [
        [Money, 2],
        [Qualities.RoastedDuck,0]
        [Qualities.Vegetarian,0]
      ]
      next: [
        {
          text: "One half of a duck later you feel inclined to commend the cook and, if possible, to take a nap. There are few things that aren't easier to face with a full belly."
          condition: [Qualities.RoastedDuck,0]
          effects: [
            [Money, -2]
            [Terror, -5]
            [Qualities.RoastedDuck,1]
          ]
        }
      ]
    },{
      kind: Location
      prompt: "The Viceroy's Palace"
      text: "The Viceroy's Palace is an ornate, stone affair. A great many statues depicting the many facets of Her Eminence's varied personality. Fountains, shrubbery, the whole lot. The guards at the front are equally decorated but their eyes are suspicious and their swords do not appear entirely for show."
      next: {
        condition: [Qualities.Favor|HerEminence, <2]
        text: "The guards are entirely polite but in no way convinced that you have any legitimate reason to entire the premises."
      }
    },{
      kind: Location
      prompt: "The Flowering Court"
      text: "A sprawling maze of waterways and little stone buildings spring off the main Spireward road."
      next: SundarsLanding|TheFloweringCourt
    }]
  }

  SundarsLanding|TheFloweringCourt {
    text: "Here among the riot of water plants the courtiers and beaurocrats of the empire are making the most of their exile with varying degrees of grace and enthusiasm. Only the very highly and very lowly regarded among the members of court end up on this side of the Gate."
    options: [{
      kind: Choice
      prompt: "Approach the Dapper Bureaucrat"
      text: "A well dressed and enthusiastic noblewoman is holding court in the most well appointed sub-magistrate's office you have ever seen."
      next: [{
        text: "You walk to the Dapper Bureaucrat's court as her previous supplicants depart. Her official stamps have been custom carved from old world mahogany and the rugs covering the floor look too expensive to step on without being arrested but she ushers you over. You walk to the petitioner's chair gingerly and accept a steaming cup of something fragrant.\n\n\"Now, how can I, Her Eminence's humble servant be of assistance to one of her loyal subjects?\""
        options: [{
          prompt: "Ask how you might be able to serve the empire"
          text: "There seems to be a great deal outside the city that might warrant attention. A valiant adventurer such as yourself could provide that attention, provided sufficient remuneration."
          next: [{
            condition: [Qualities.Quest|DapperBureaucrat, 0]
            text: "\"I am surprised and flattered that you think I, a lowly sub-magistrate, has the power to influence our foreign policy beyond the walls. You are in luck, however. In the course of my duties I happen to have heard of a small issue. If that issue were to be resolved I am confident I could arrange a small dispensation\""
            effects: [
              Quests.SimpleEmpireQuest,
              [Qualities.Quest|DapperBureaucrat, 1]
            ]
          }]
        }]
      }]
    }]
  }
}