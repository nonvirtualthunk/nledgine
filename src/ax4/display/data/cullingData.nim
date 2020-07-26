
import Sets
import Tables
import hex
import prelude
import arxmath
import worlds

type
   CullingData* = object
      cameraCenter*: AxialVec
      hexesInView*: HashSet[AxialVec]
      hexesByCartesianCoord*: seq[AxialVec]
      revision*: int


defineDisplayReflection(CullingData)
