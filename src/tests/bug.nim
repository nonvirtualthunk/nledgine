

type
  BazEnum* = enum
    A,
    B

  Discriminator* = enum
    Y,
    Z

  Foo* = object
    bars*: seq[Bar]

  Bar* = object
    case kind*: Discriminator
    of Y:
      enumValue*: BazEnum
    of Z:
      i*: int


let x = new Foo

const b = Bar(kind: Discriminator.Y, enumValue: B)
x[] = Foo(bars: @[b])
echo "enumValue: ", x.bars[0].enumValue # Prints "A"

x[] = Foo(bars: @[Bar(kind: Discriminator.Y, enumValue: B)])
echo "enumValue: ", x.bars[0].enumValue # Prints "B"