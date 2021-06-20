import tables
import graphics/images
import config/config_core
import graphics/fonts
import noto
import options

export config_core
export images

const ProjectName* {.strdefine.} : string = "project"

{.experimental.}

type
  Resources = ref object
    images: Table[string, Image]
    config: Table[string, ConfigValue]
    fonts: Table[string, ArxTypeface]

    imageChannel: ptr Channel[Image]
    configChannel: ptr Channel[ConfigValue]
    fontChannel: ptr Channel[ArxTypeface]

  ResourceRequestKind = enum
    ImageRequest
    ConfigRequest
    FontRequest
    ExitRequest

  ResourceRequest = object
    path: string
    acceptAbsence: bool
    case kind: ResourceRequestKind:
    of ImageRequest:
      imageChannel: ptr Channel[Image]
    of ConfigRequest:
      configChannel: ptr Channel[ConfigValue]
    of FontRequest:
      fontChannel: ptr Channel[ArxTypeface]
    of ExitRequest:
      discard

var globalResources {.threadvar.}: Resources

var requestChannel: Channel[ResourceRequest]
requestChannel.open()

var resourcesThread: Thread[void]

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
        discard request.imageChannel.trySend(cur)
    of ConfigRequest:
      var cur = r.config.getOrDefault(request.path)
      if cur.isEmpty:
        try:
          let configStr = readFile("resources/" & request.path)
          cur = parseConfig(configStr)
        except IoError:
          if not request.acceptAbsence:
            err &"Could not load config file: {request.path}"
          cur = ConfigValue()
        r.config[request.path] = cur
      if request.configChannel != nil:
        discard request.configChannel.trySend(cur)
    of FontRequest:
      var cur = r.fonts.getOrDefault(request.path)
      if cur == nil:
        cur = loadArxTypeface("resources/fonts/" & request.path)
        r.fonts[request.path] = cur
      if request.fontChannel != nil:
        discard request.fontChannel.trySend(cur)

createThread(resourcesThread, loadResources)


proc getGlobalResources(): Resources =
  if globalResources == nil:
    globalResources = new Resources
    globalResources.imageChannel = createShared(Channel[Image])
    globalResources.imageChannel.open()
    globalResources.configChannel = createShared(Channel[ConfigValue])
    globalResources.configChannel.open()
    globalResources.fontChannel = createShared(Channel[ArxTypeface])
    globalResources.fontChannel.open()
  globalResources

proc image*(path: string): Image =
  let r = getGlobalResources()
  var cur = r.images.getOrDefault(path)
  if cur == nil:
    requestChannel.send(ResourceRequest(kind: ImageRequest, path: path, imageChannel: r.imageChannel))
    cur = r.imageChannel.recv()
    r.images[path] = cur
  cur


proc font*(path: string): ArxTypeface =
  let r = getGlobalResources()
  var cur = r.fonts.getOrDefault(path)
  if cur == nil:
    requestChannel.send(ResourceRequest(kind: FontRequest, path: path, fontChannel: r.fontChannel))
    cur = r.fontChannel.recv()
    r.fonts[path] = cur
  cur


proc typeface*(path: string): ArxTypeface =
  font(path)

proc config*(path: string) : ConfigValue =
  let r = getGlobalResources()
  # todo: is this doing a bunch of copying behind the scenes?
  var cur = r.config.getOrDefault(path)
  if cur.isEmpty:
    requestChannel.send(ResourceRequest(kind: ConfigRequest, path: path, configChannel: r.configChannel))
    assert r.configChannel != nil
    cur = r.configChannel.recv()
    r.config[path] = cur
  cur

proc configOpt*(path: string) : Option[ConfigValue] =
  let r = getGlobalResources()
  # todo: is this doing a bunch of copying behind the scenes?
  var cur = r.config.getOrDefault(path)
  if cur.isEmpty:
    requestChannel.send(ResourceRequest(kind: ConfigRequest, path: path, configChannel: r.configChannel))
    assert r.configChannel != nil
    cur = r.configChannel.recv()
    r.config[path] = cur
  if cur.isEmpty:
    none(ConfigValue)
  else:
    some(cur)

proc preloadImage*(path: string) =
  requestChannel.send(ResourceRequest(kind: ImageRequest, path: path))

proc preloadConfig*(path: string) =
  requestChannel.send(ResourceRequest(kind: ConfigRequest, path: path))

proc preloadFont*(path: string) =
  requestChannel.send(ResourceRequest(kind: FontRequest, path: path))



proc readFromConfig*(cv: ConfigValue, v: var ArxTypeface) =
  if cv.isStr:
    v = font(cv.str)
  else:
    warn &"could not load font from config value : {cv}"

when isMainModule:
  let taxonomyConfig = config("data/taxonomy.sml")

  assert not taxonomyConfig["Taxonomy"].isEmpty
  assert taxonomyConfig["Taxonomy"]["Materials"]["Wood"].asStr == "Material"
