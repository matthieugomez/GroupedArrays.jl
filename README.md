[![Build status](https://github.com/matthieugomez/GroupedArrays.jl/workflows/CI/badge.svg)](https://github.com/matthieugomez/GroupedArrays.jl/actions)

## Installation
The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry and so can be installed at the REPL with 

`] add GroupedArrays`.

## Motivation
`GroupedArray` returns an `AbstractArray` with integers corresponding to each group.

`GroupedArray` can be used to combine multiple vectors
```julia
using GroupedArrays
p1 = repeat(["a", "b", "c"], inner = 2)
g = GroupedArray(p1)

p2 = repeat(["d", "e"], outer = 3)
g = GroupedArray(p1, p2)
```