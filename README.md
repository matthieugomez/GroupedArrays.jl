[![Build status](https://github.com/matthieugomez/GroupedArrays.jl/workflows/CI/badge.svg)](https://github.com/matthieugomez/GroupedArrays.jl/actions)

## Installation
The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry and so can be installed at the REPL with 

`] add GroupedArrays`.

## Motivation
This package makes it easier to store data with repeated values.
Compared to PooledDataArrays, the pool are simply the reference level, except that zero is interepreted as missing.

Moreover, it allows one to combine multiple vectors
```julia
using GroupedArrays
p1 = repeat(1:5, inner = 2)
g = GroupedArray(p1)
p2 = repeat(1:5, outer = 2)
g = GroupedArray(p1, p2)
```