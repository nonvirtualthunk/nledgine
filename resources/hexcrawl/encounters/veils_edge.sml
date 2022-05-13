Encounters {
  VeilsEdge|Initial {
    text: "For a hundred hundred years an impenetrable veil lay across the western edge of the world and the mightiest magics could not pierce it. Ten years ago it fell. Now adventurers, conquerors, and scholars converge from all the corners of the world to explore and carve a name for themselves in the uncharted lands beyond the veil."
    options: [{
      kind: Choice
      prompt: "Continue..."
      hidden: true
      requirement: [Qualities.Sellsword, 1]
      next: VeilsEdge|Initial|Sellsword
    }]
  }

  VeilsEdge|Initial|Sellsword {
    text: "The merchant prince you served last tried to sell you out once you'd hewn a path through his rivals and outlived your usefulness. Only your quick reflexes and suspicious nature saved you from the ambush where your company perished. You took some satisfaction in repaying the prince in kind, he can keep your companions company until you arrive."
    options: [{
      kind: Choice
      prompt: "Continue..."
      next: VeilsEdge|Initial|Sellsword|2
    }]
  }

  VeilsEdge|Initial|Sellsword|2 {
    text: "After the prince's unplanned departure from the highest window of his tower you found it desirable to be elsewhere. Hearing the tales of opportunity in the untravelled lands you wandered west until at last tired and nearly broke you have arrived at Veil's Edge Tavern."
    options: [{
      kind: Choice
      prompt: "Continue..."
      next: VeilsEdge|Tavern
    }]
  }

  VeilsEdge|Tavern {
    text: "The Veil's Edge Tavern is the raucous heart of the growing town at the edge of the wilds. Once a modest house for the few scholars who studied the Veil it has expanded haphazardly in all directions into a bewildering and ramshackle warren. The common room is filled with laughter, song, ale and smoke, illuminated by a handful of lamps and a roaring hearth"
    options: [{
      kind: Choice
      prompt: "Get into a fight"
      text: "It's been a little while since you last got into a brawl, you could use some practice"
      next: [VeilsEdge|Tavern|FightDandy]
    }]
  }

  VeilsEdge|Tavern|FightDandy {
    text: "You swagger up to a proud and not entirely sober young man who is regaling the nearby crowd with tales of his exploits. A skeptical comment and a raised eyebrow are all it takes to get the man and his friends in a brawling mood."
    options: [{
      kind: Choice
      prompt: "Brawl!"
      challenge: [Combat, 3, Dandy]
    }]
  }
}