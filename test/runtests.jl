using Test, GroupedArrays

N = 10
a1 = collect(1:N)
g1 = GroupedArray(a1)
@test size(g1) == (N,)
@test length(g1) == N
@test g1[1] == 1
@test g1[1:2] == [1, 2]
@test g1[g1.<=2] == g1[[1,2]] == g1[1:2]

a2 = [1,2]
@test_throws DimensionMismatch GroupedArray(a1, a2)



p1 = repeat(1:5, inner = 2)
p1_missing = repeat([missing, 1, 2, 3, 4], inner = 2)
p2 = repeat(1:5, outer = 2)


g = GroupedArray(p1, p2)
g = GroupedArray(p1_missing, p2)
g[1] == 0


using CategoricalArrays
g = GroupedArray(categorical(p1), categorical(p2))

using PooledArrays
g = GroupedArray(PooledArray(p1), PooledArray(p2))


g = GroupedArray([ 0 1 ; 1 0])
