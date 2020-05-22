import metric
import sugar
import times

export metric
export sugar

type UnitOfTime* = Metric[metric.Time,float]


let programStartTime* = now()


proc microseconds*(f : float) : UnitOfTime =
    (f / 1000000.0) * metric.second

proc relTime*() : UnitOfTime =
    let dur = now() - programStartTime
    return inMicroseconds(dur).float.microseconds