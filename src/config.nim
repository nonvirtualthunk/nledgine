import config/config_core
import config/config_binding
import config/config_helpers
import arxregex


export config_core
export config_binding
export config_helpers

const wordNumberPattern* = re"([a-zA-Z0-9]+)\s?\(([+-]?[0-9]+)\)"
const wordWordPattern* = re"([a-zA-Z0-9]+)\s?\((.+)\)"
