[![Build status](https://github.com/matthieugomez/GroupedArrays.jl/workflows/CI/badge.svg)](https://github.com/matthieugomez/GroupedArrays.jl/actions)

## Installation
The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry and so can be installed at the REPL with 

`] add GroupedArrays`.

## Motivation
`GroupedArray` returns an `AbstractArray` with integers corresponding to each group (or a `missing` for groups with `missing`).

```julia
using GroupedArrays
p = repeat(["a", "b", missing], outer = 2)
g = GroupedArray(p)
# 6-element GroupedArray{Int64, 1}:
#  1
#  2
#   missing
#  1
#  2
#   missing
```

Use the keyword argument `coalesce = true` to consider missing values as distinct
```julia
using GroupedArrays
p = repeat(["a", "b", missing], outer = 2)
g = GroupedArray(p; coalesce = true)
# 6-element GroupedArray{Int64, 1}:
#  1
#  2
#  3
#  1
#  2
#  3
```

`GroupedArray` can be used to compute groups across multiple vectors:
```julia
p1 = repeat(["a", "b"], outer = 3)
p2 = repeat(["d", "e"], inner = 3)
g = GroupedArray(p1, p2)
# 6-element GroupedArray{Int64, 1}:
#  1
#  2
#  1
#  3
#  4
#  3
```


## See also
Internally, a `GroupedArray` is stored as a vector of Integers, where 0 corresponds to `missing`. 

The underlying code of `GroupedArrays` is taken from [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl)
`GroupedArrays`can be seen as [PooledArrays](https://github.com/JuliaData/PooledArrays.jl) restricted to arrays of integer/missing values


