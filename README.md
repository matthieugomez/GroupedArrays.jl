[![Build status](https://github.com/matthieugomez/GroupedArrays.jl/workflows/CI/badge.svg)](https://github.com/matthieugomez/GroupedArrays.jl/actions)

## Installation
The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry and so can be installed at the REPL with 

`] add GroupedArrays`.

## Motivation
`GroupedArray` returns an `AbstractArray` with integers corresponding to each group.

```julia
using GroupedArrays
p1 = repeat(["a", "b"], inner = 3)
g = GroupedArray(p1)
# 6-element GroupedArray{Int64, 1}:
#  1
#  1
#  1
#  2
#  2
#  2
```

`GroupedArray` can be used to compute groups across multiple vectors:

```julia
p2 = repeat(["d", "e"], outer = 3)
g = GroupedArray(p1, p2)
# 6-element GroupedArray{Int64, 1}:
#  1
#  2
#  1
#  3
#  4
#  3
```