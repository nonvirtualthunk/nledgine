import worlds
import reflect
import tables
import graphics/images
import config

type
    Resources* = object
        images : Table[string, Image]
        config : Table[string, ConfigValue]

defineReflection(Resources)



proc image*(r : ref Resources, path : string) : Image =
    var cur = r.images.getOrDefault(path)
    if cur == nil:
        cur = loadImage("resources/" & path)
        r.images[path] = cur
    cur

proc config*(r : ref Resources, path : string) : ConfigValue =
    # todo: is this doing a bunch of copying behind the scenes?
    var cur = r.config.getOrDefault(path)
    if cur.isEmpty:
        let configStr = readFile("resources/" & path)
        cur = parseConfig(configStr)
        r.config[path] = cur
    cur