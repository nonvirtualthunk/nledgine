import game/library
import worlds/taxonomy
import options
import images
import image_extras
import config
import resources
import strformat

export library

type
   TaxonomyDisplay* = object
      icon*: Option[ImageLike]

defineSimpleReadFromConfig(TaxonomyDisplay)



defineLibrary[TaxonomyDisplay]:
   var lib = new Library[TaxonomyDisplay]
   when defined(ProjectName):
     let conf = resources.config(&"{ProjectName}/taxonomy_display.sml")
   else:
     let conf = resources.config("display/taxonomy_display.sml")

   proc process(keyAccum: string, cv: ConfigValue) =
      if cv.isObj:
         if cv.hasField("icon"):
            let t = qualifiedTaxon(keyAccum)
            let tmp = new TaxonomyDisplay
            cv.readInto(tmp[])
            lib[t] = tmp
         else:
            for k, v in cv:
               process(keyAccum & "." & k, v)

   for k, v in conf["TaxonomyDisplay"]:
      process(k, v)
   lib
