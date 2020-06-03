import tables
import graphics/images
import config

export config
export images

{.experimental.}

type
    Resources = ref object
        images : Table[string, Image]
        config : Table[string, ConfigValue]

        imageChannel : ptr Channel[Image]
        configChannel : ptr Channel[ConfigValue]

    ResourceRequestKind = enum
        ImageRequest
        ConfigRequest
        ExitRequest

    ResourceRequest = object
        path : string
        case kind : ResourceRequestKind:
        of ImageRequest:
            imageChannel : ptr Channel[Image]
        of ConfigRequest:
            configChannel : ptr Channel[ConfigValue]
        of ExitRequest: 
            discard

var globalResources {.threadvar.} : Resources

var requestChannel : Channel[ResourceRequest]
requestChannel.open()

var resourcesThread : Thread[void]

proc loadResources() {.thread.} =
    let r = new Resources
    while true:
        let request = requestChannel.recv()
        case request.kind:
        of ExitRequest: break
        of ImageRequest:
            var cur = r.images.getOrDefault(request.path)
            if cur == nil:
                cur = loadImage("resources/" & request.path)
                r.images[request.path] = cur
            if request.imageChannel != nil:
                request.imageChannel.send(cur)
        of ConfigRequest:
            var cur = r.config.getOrDefault(request.path)
            if cur.isEmpty:
                let configStr = readFile("resources/" & request.path)
                cur = parseConfig(configStr)
                r.config[request.path] = cur
            if request.configChannel != nil:
                request.configChannel.send(cur)

createThread(resourcesThread, loadResources)
            

proc getGlobalResources() : Resources =
    if globalResources == nil:
        globalResources = new Resources
        globalResources.imageChannel = createShared(Channel[Image])
        globalResources.imageChannel.open()
        globalResources.configChannel = createShared(Channel[ConfigValue])
        globalResources.configChannel.open()
    globalResources

proc image*(path : string) : Image =
    let r = getGlobalResources()
    var cur = r.images.getOrDefault(path)
    if cur == nil:
        requestChannel.send(ResourceRequest(kind : ImageRequest, path : path, imageChannel : r.imageChannel))
        cur = r.imageChannel.recv()
        r.images[path] = cur
    cur

proc config*(path : string) : ConfigValue =
    let r = getGlobalResources()
    # todo: is this doing a bunch of copying behind the scenes?
    var cur = r.config.getOrDefault(path)
    if cur.isEmpty:
        requestChannel.send(ResourceRequest(kind : ConfigRequest, path : path, configChannel : r.configChannel))
        assert r.configChannel != nil
        cur = r.configChannel.recv()
        r.config[path] = cur
    cur

proc preloadImage*(path : string) =
    requestChannel.send(ResourceRequest(kind : ImageRequest, path : path))

proc preloadConfig*(path : string) =
    requestChannel.send(ResourceRequest(kind : ConfigRequest, path : path))


when isMainModule:
    let taxonomyConfig = config("data/taxonomy.sml")

    assert not taxonomyConfig["Taxonomy"].isEmpty
    assert taxonomyConfig["Taxonomy"]["Materials"]["Wood"].asStr == "Material"