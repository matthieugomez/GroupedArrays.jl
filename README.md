[![Build status](https://github.com/FixedEffects/GroupedArrays.jl/workflows/CI/badge.svg)](https://github.com/FixedEffects/GroupedArrays.jl/actions)

## Installation
The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry and so can be installed at the REPL with 

`] add GroupedArrays`.

## Introduction
GroupedArray is an AbstractArray that contains positive integers or missing values.

- `GroupedArray(x::AbstractArray)` returns a `GroupedArray` of the same length as the original array, where each distinct value is encoded by a distinct integer.
- `GroupedArray(xs...::AbstractArray)` returns a `GroupedArray` where each distinct combination of values is encoded by a distinct integer 
- By default, `GroupedArray` groups all `missing` values into a distinct `missing` category. With `coalesce = true`, missing values are not treated differently.

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

- `GroupedArray(xs::AbstractArray...)` combine groups defined by multiple vectors:
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

## Relation to other packages
- `GroupedArray` is similar to `PooledArray`, except that the pool is simply the set of integers from 1 to n where n is the number of groups(`missing` is encoded as 0). This allows for faster lookup in setups where the group value is not meaningful.
- The algorithm to group multiple vectors is taken from [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl)



