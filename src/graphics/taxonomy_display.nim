import game/library
import worlds/taxonomy
import options
import images
import image_extras
import config
import resources

export library

type
   TaxonomyDisplay* = object
      icon*: Option[ImageLike]

defineSimpleReadFromConfig(TaxonomyDisplay)



defineLibrary[TaxonomyDisplay]:
   var lib = new Library[TaxonomyDisplay]
   let conf = resources.config("display/taxonomy_display.sml")

   proc process(keyAccum: string, cv: ConfigValue) =
      if cv.isObj:
         if cv.hasField("icon"):
            let t = qualifiedTaxon(keyAccum)
            lib[t] = readInto(cv, TaxonomyDisplay)
         else:
            for k, v in cv:
               process(keyAccum & "." & k, v)

   for k, v in conf["TaxonomyDisplay"]:
      process(k, v)
   lib
