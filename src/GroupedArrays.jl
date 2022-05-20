module GroupedArrays
using Missings
using DataAPI
using Base.Threads
include("spawn.jl")
include("utils.jl")

"""
GroupedArray{T,N} <: AbstractArray{T,N}
N-dimensional dense array with elements of type T, where T <: Union{Int, Missing}
"""
mutable struct GroupedArray{T <: Union{Int, Missing}, N} <: AbstractArray{T, N}
	groups::Array{Int, N} 
	ngroups::Int
end
const GroupedVector{T} = GroupedArray{T, 1}
const GroupedMatrix{T} = GroupedArray{T, 2}

##############################################################################
##
## Arrays API
##
##############################################################################

Base.size(g::GroupedArray) = size(g.groups)
Base.IndexStyle(g::GroupedArray) = Base.IndexLinear()
Base.LinearIndices(g::GroupedArray) = LinearIndices(g.groups)

Base.@propagate_inbounds function Base.getindex(g::GroupedArray{Int}, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds g.groups[i]
end

Base.@propagate_inbounds function Base.getindex(g::GroupedArray, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.groups[i]
	x == 0 ? missing : x
end

Base.@propagate_inbounds function Base.setindex!(g::GroupedArray, x::Number,  i::Number)
	@boundscheck checkbounds(g, i)
	x > 0 || throw(ArgumentError("The number x must be positive"))
	x > g.ngroups && (g.ngroups = x)
	@inbounds g.groups[i] = x
end

Base.@propagate_inbounds function Base.setindex!(g::GroupedArray{T}, ::Missing,  i::Number) where {T >: Missing}
	@boundscheck checkbounds(g, i)
	@inbounds g.groups[i] = 0
end

##############################################################################
##
## Constructor
##
##############################################################################

"""

	GroupedArray(args... [; coalesce = false, sort = nothing])

Construct a `GroupedArray` taking on distinct values for the groups formed by elements of `args`

### Arguments
* `args...`: `AbstractArrays` of same sizes.

### Keyword arguments
* `coalesce::Bool`: should missing values considered as distinct grotups indicators?
* `sort::Union{Bool, Nothing}`: should the order of the groups be the sort order?

### Examples
```julia
using GroupedArrays
p1 = ["a", "a", "b", "b", missing, missing]
GroupedArray(p1)
GroupedArray(p1; coalesce = true)
p2 = [1, 1, 1, 2, 2, 2]
GroupedArray(p1, p2)
```
"""
function GroupedArray(args...; coalesce = false, sort = nothing)
	all(x isa AbstractArray for x in args) || throw(DimensionMismatch("arguments are not AbstractArrays"))
	s = size(first(args)) 
	all(size(x) == s for x in args) || throw(DimensionMismatch("cannot match array  sizes"))
	groups = Vector{Int}(undef, prod(s))
	ngroups, rhashes, gslots, sorted = row_group_slots(vec.(args), Val(false), groups, !coalesce, sort)
	# sort groups if row_group_slots hasn't already done that
	if sort === true && !sorted
		idx = find_index(GroupedVector{Int}(groups, ngroups))
		group_invperm = invperm(sortperm(collect(zip(map(x -> view(x, idx), args)...))))
		@inbounds for (i, gix) in enumerate(groups)
			groups[i] = gix > 0 ? group_invperm[gix] : 0
		end
	end
	T = !coalesce && any(eltype(x) >: Missing for x in args) ? Union{Int, Missing} : Int
	GroupedArray{T, length(s)}(reshape(groups, s), ngroups)
end

# Find index of representative row for each group
function find_index(g::GroupedArray)
	groups, ngroups = g.groups, g.ngroups
	idx = Vector{Int}(undef, ngroups)
	filled = fill(false, ngroups)
	nfilled = 0
	@inbounds for (i, gix) in enumerate(groups)
		if gix > 0 && !filled[gix]
			filled[gix] = true
			idx[gix] = i
			nfilled += 1
			nfilled == ngroups && break
		end
	end
	return idx
end


##############################################################################
##
## Conversions
##
##############################################################################
Base.convert(::Type{GroupedArray{T, N}}, g::GroupedArray{T, N}) where {T, N} = g
function Base.convert(::Type{GroupedArray{Union{Int, Missing},N}}, g::GroupedArray{Int, N}) where {N}
    return GroupedArray{Union{Int, Missing},N}(g.groups, g.ngroups)
end
function Base.convert(::Type{GroupedArray{Int, N}}, g::GroupedArray{Union{Int, Missing}, N}) where {N}
	@assert all(x > 0 for x in g.groups)
    return GroupedArray{Int,N}(g.groups, g.ngroups)
end

Base.convert(::Type{GroupedArray}, g::GroupedArray) = g

function Base.convert(::Type{GroupedArray{T,N}}, a::AbstractArray) where {T, N}
    convert(GroupedArray{T, N}, GroupedArray(a))
end
Base.convert(::Type{GroupedArray}, a::AbstractArray) = GroupedArray(a)


##############################################################################
##
## Data API
##
##############################################################################

DataAPI.refarray(g::GroupedArray) = g.groups
DataAPI.levels(g::GroupedArray) = 1:g.ngroups
DataAPI.refvalue(g::GroupedArray, ref::Integer) = ref > 0 ? ref : missing

# refpool is such that refpool[refarray[i]] = x
struct GroupedRefPool{T <: Union{Int, Missing}} <: AbstractVector{T}
	ngroups::Int
end
Base.size(x::GroupedRefPool{T}) where T = (x.ngroups + (T >: Missing),)
Base.axes(x::GroupedRefPool{T}) where T = ((1-(T >: Missing)):x.ngroups,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.LinearIndices(x::GroupedRefPool) = axes(x, 1)

@inline function Base.getindex(x::GroupedRefPool{T}, i::Integer) where T
    @boundscheck checkbounds(x, i)
    T >: Missing && i == 0 ? missing : i
end
Base.allunique(x::GroupedRefPool) = true

DataAPI.refpool(g::GroupedArray{T}) where {T} = GroupedRefPool{T}(g.ngroups)
# invrefpool is such that invrefpool[refpool[x]] = x. 
# In words, for each element of refpool, it associates the corresponding index in the pool
# here, this gives
#  missing -> 0 
#  i -> i for 1 ≤ i ≤ ngroups
struct GroupedInvRefPool{T}
	ngroups::Int
end
@inline Base.haskey(x::GroupedInvRefPool{T}, ::Missing) where {T} = T >: Missing
@inline Base.haskey(x::GroupedInvRefPool, v::Integer) = 1 <= v <= x.ngroups
@inline function Base.getindex(x::GroupedInvRefPool{T}, ::Missing) where {T}
	@boundscheck T >: Missing
	0
end
@inline function Base.getindex(x::GroupedInvRefPool, i::Integer)
	@boundscheck 1 <= i <= x.ngroups
	i
end
@inline Base.get(x::GroupedInvRefPool{T}, ::Missing, default) where {T} = T >: Missing ? 0 : default
@inline Base.get(x::GroupedInvRefPool, i::Integer, default) = 1 <= v <= x.ngroups ? i : default
DataAPI.invrefpool(g::GroupedArray{T}) where {T} = GroupedInvRefPool{T}(g.ngroups)


export GroupedArray, GroupedVector, GroupedMatrix
end # module
