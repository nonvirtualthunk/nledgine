Qualities {
  Background {

  }

  Urchin {
    name: "Urchin"
    description: "Before you passed through the gate you learned your lessons among the downtrodden of the capital. Here you could have been anyone."
    isA: Qualities.Background
  }

  Sellsword {
    name: "Sellsword"
    description: "You have killed men, you have been paid. Death is your constant companion and you maintain an amiable conversation."
    isA: Qualities.Background
  }

  AWorryingDebt {
    name: "A Worrying Debt"
    description: "You incurred a debt to make it through the Gate. How will it be repaid?"
  }

  RecruitingAtTheGate {
    hidden: true
    reset: "10 days"
  }

  RoastedDuck {
    hidden: true
    reset: "10 days"
  }

  Vegetarian {
    name: "Vegetarian"
    description: "You do not partake of the flesh of animals. Perhaps they will be so kind as to extend you a similar courtesy.."
  }

  Favor|HerEminence {
    name: "Favor: Her Eminence"
    description: "The representatives of Her Eminence have cause to regard you favorably when they deign to regard you at all."
  }

  Quest|DapperBureaucrat {
    name: "Quest: Dapper Bureaucrat"
    description: "The Dapper Bureaucrat has trusted you with a discreet task. You will need to complete it before she considers burdening you with another."
  }
}