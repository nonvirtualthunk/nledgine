
import Sets
import Tables
import hex
import prelude
import arxmath

type
   CullingData* = object
      cameraCenter* : AxialVec
      hexesInView* : HashSet[AxialVec]
      hexesByCartesianCoord* : seq[AxialVec]
      revision* : int


defineReflection(CullingData)