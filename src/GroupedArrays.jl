module GroupedArrays
using Missings
using DataAPI
using Base.Threads
include("spawn.jl")
include("utils.jl")
mutable struct GroupedArray{N} <: AbstractArray{Union{Int, Missing}, N}
	refs::Array{Int, N}   # refs must be between 0 and n. 0 means missing
	ngroups::Int          # Number of potential values (>= maximum(refs))
end
Base.size(g::GroupedArray) = size(g.refs)
Base.axes(g::GroupedArray) = axes(g.refs)
Base.IndexStyle(g::GroupedArray) = Base.IndexLinear()
Base.LinearIndices(g::GroupedArray) = axes(g.refs, 1)

Base.@propagate_inbounds function Base.getindex(g::GroupedArray, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
	x == 0 ? missing : x
end
Base.@propagate_inbounds function Base.setindex!(g::GroupedArray, x::Missing,  i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds g.refs[i] = 0
end
Base.@propagate_inbounds function Base.setindex!(g::GroupedArray, x::Number,  i::Number)
	@boundscheck checkbounds(g, i)
	x <= 0 && throw(ArgumentError("The number x must be positive"))
	x > g.ngroups && (g.ngroups = x)
	@inbounds g.refs[i] = x
end

# Constructor
function GroupedArray(args...; coalesce = false)
	s = size(args[1])
	for x in args
		size(x) == s || throw(DimensionMismatch("cannot match array  sizes"))
	end
	groups = Vector{Int}(undef, length(args[1]))
	ngroups, rhashes, gslots, sorted = row_group_slots(map(vec, args), Val(false), groups, !coalesce, false)
	GroupedArray{length(s)}(reshape(groups, s), ngroups)
end


# Data API
DataAPI.refarray(g::GroupedArray) = g.refs
DataAPI.levels(g::GroupedArray) = 1:g.ngroups
function DataAPI.refvalue(g::GroupedArray, ref::Integer)
	ref > 0 ? ref : missing
end
# refpool is such that refpool[refarray[i]] = x
struct GroupedRefPool <: AbstractVector{Union{Int, Missing}}
	ngroups::Int
end
Base.size(x::GroupedRefPool) = (x.ngroups + 1,)
Base.axes(x::GroupedRefPool) = (0:x.ngroups,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(x::GroupedRefPool, i::Integer)
    @boundscheck checkbounds(x, i)
    i > 0 ? i : missing
end
Base.LinearIndices(x::GroupedRefPool) = axes(x, 1)
Base.allunique(x::GroupedRefPool) = true
DataAPI.refpool(g::GroupedArray) = GroupedRefPool(g.ngroups)
# invrefpool is such that invrefpool[refpool[x]] = x. Basically, it gives the index in the pool (so the ref level) corresponding to each element of refpool
# so it should be missing -> 0 and i -> i for 1 ≤ i ≤ g.ngroups
struct GroupedInvRefPool
	ngroups::Int
end
@inline Base.haskey(x::GroupedInvRefPool, v::Missing) = true
@inline Base.haskey(x::GroupedInvRefPool, v::Integer) = (v >= 1) & (v <= x.ngroups)
@inline Base.getindex(x::GroupedInvRefPool, v::Missing) = 0
@inline function Base.getindex(x::GroupedInvRefPool, v::Integer)
	@boundscheck (v >= 1) & (v <= x.ngroups)
	v
end
@inline Base.get(x::GroupedInvRefPool, v::Missing, default)  = 0
@inline function Base.get(x::GroupedInvRefPool, v::Integer, default)
	((v >= 1) & (v <= x.ngroups)) ? v : default
end
DataAPI.invrefpool(g::GroupedArray) = GroupedInvRefPool(g.ngroups)




export GroupedArray
end # module
