import tables
import graphics/images
import config/config_core
import typography
import graphics/fonts
import noto

export config_core
export images

{.experimental.}

type
   Resources = ref object
      images: Table[string, Image]
      config: Table[string, ConfigValue]
      fonts: Table[string, ArxFontRoot]

      imageChannel: ptr Channel[Image]
      configChannel: ptr Channel[ConfigValue]
      fontChannel: ptr Channel[ArxFontRoot]

   ResourceRequestKind = enum
      ImageRequest
      ConfigRequest
      FontRequest
      ExitRequest

   ResourceRequest = object
      path: string
      case kind: ResourceRequestKind:
      of ImageRequest:
         imageChannel: ptr Channel[Image]
      of ConfigRequest:
         configChannel: ptr Channel[ConfigValue]
      of FontRequest:
         fontChannel: ptr Channel[ArxFontRoot]
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
            let configStr = readFile("resources/" & request.path)
            cur = parseConfig(configStr)
            r.config[request.path] = cur
         if request.configChannel != nil:
            discard request.configChannel.trySend(cur)
      of FontRequest:
         var cur = r.fonts.getOrDefault(request.path)
         if cur == nil:
            cur = loadArxFont("resources/fonts/" & request.path)
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
      globalResources.fontChannel = createShared(Channel[ArxFontRoot])
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


proc font*(path: string): ArxFontRoot =
   let r = getGlobalResources()
   var cur = r.fonts.getOrDefault(path)
   if cur == nil:
      requestChannel.send(ResourceRequest(kind: FontRequest, path: path, fontChannel: r.fontChannel))
      cur = r.fontChannel.recv()
      r.fonts[path] = cur
   cur


proc config*(path: string): ConfigValue =
   let r = getGlobalResources()
   # todo: is this doing a bunch of copying behind the scenes?
   var cur = r.config.getOrDefault(path)
   if cur.isEmpty:
      requestChannel.send(ResourceRequest(kind: ConfigRequest, path: path, configChannel: r.configChannel))
      assert r.configChannel != nil
      cur = r.configChannel.recv()
      r.config[path] = cur
   cur

proc preloadImage*(path: string) =
   requestChannel.send(ResourceRequest(kind: ImageRequest, path: path))

proc preloadConfig*(path: string) =
   requestChannel.send(ResourceRequest(kind: ConfigRequest, path: path))

proc preloadFont*(path: string) =
   requestChannel.send(ResourceRequest(kind: FontRequest, path: path))



proc readFromConfig*(cv: ConfigValue, v: var ArxFontRoot) =
   if cv.isStr:
      v = font(cv.str)
   else:
      warn &"could not load font from config value : {cv}"

when isMainModule:
   let taxonomyConfig = config("data/taxonomy.sml")

   assert not taxonomyConfig["Taxonomy"].isEmpty
   assert taxonomyConfig["Taxonomy"]["Materials"]["Wood"].asStr == "Material"