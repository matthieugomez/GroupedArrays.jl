module GroupedArrays
using Missings
using DataAPI
using Base.Threads
include("spawn.jl")
include("utils.jl")
mutable struct GroupedArray{T <: Union{Int, Missing}, N} <: AbstractArray{T, N}
	refs::Array{Int, N}   # refs must be between 0 and n. 0 means missing
	ngroups::Int          # Number of potential values (as a contract, we always have ngroups >= maximum(refs))
end
Base.size(g::GroupedArray) = size(g.refs)
Base.axes(g::GroupedArray) = axes(g.refs)
Base.IndexStyle(g::GroupedArray) = Base.IndexLinear()
Base.LinearIndices(g::GroupedArray) = axes(g.refs, 1)

Base.@propagate_inbounds function Base.getindex(g::GroupedArray{Int}, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds g.refs[i]
end

Base.@propagate_inbounds function Base.getindex(g::GroupedArray, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
	return x == 0 ? missing : x
end

Base.@propagate_inbounds function Base.setindex!(g::GroupedArray, x::Number,  i::Number)
	@boundscheck checkbounds(g, i)
	x > 0 || throw(ArgumentError("The number x must be positive"))
	x > g.ngroups && (g.ngroups = x)
	@inbounds g.refs[i] = x
end

Base.@propagate_inbounds function Base.setindex!(g::GroupedArray{T}, x::Missing,  i::Number) where {T >: Missing}
	@boundscheck checkbounds(g, i)
	@inbounds g.refs[i] = 0
end
"""
Constructor for GroupedArrays

GroupedArray constructor always promises that all elements between 1 and ngroups (included) are presented in refs. However, this is not necessarly true aftewards (setindex! does not check that the replaced ref corresponds to the last one)

if coalesce = true, missing values are associated an integer
if sort = false, groups are created in order of appearances. If sort = true, groups are sorted. If sort = nothing, fastest algorithm is used.
"""
function GroupedArray(args...; coalesce = false, sort = nothing)
	s = size(args[1])
	all(size(x) == s for x in args) || throw(DimensionMismatch("cannot match array  sizes"))
	groups = Vector{Int}(undef, prod(s))
	ngroups, rhashes, gslots, sorted = row_group_slots(vec.(args), Val(false), groups, !coalesce, sort)
	T = !coalesce && any(eltype(x) >: Missing for x in args) ? Union{Int, Missing} : Int
	GroupedArray{T, length(s)}(reshape(groups, s), ngroups)
end





# Data API
DataAPI.refarray(g::GroupedArray) = g.refs
DataAPI.levels(g::GroupedArray) = 1:g.ngroups
DataAPI.refvalue(g::GroupedArray, ref::Integer) = ref > 0 ? ref : missing

# refpool is such that refpool[refarray[i]] = x
struct GroupedRefPool{T <: Union{Int, Missing}} <: AbstractVector{T}
	ngroups::Int
end
Base.size(x::GroupedRefPool{T}) where T = (x.ngroups + (T >: Missing),)
Base.axes(x::GroupedRefPool{T}) where T = ((1-(T >: Missing)):x.ngroups,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(x::GroupedRefPool{T}, i::Integer) where T
    @boundscheck checkbounds(x, i)
    return T >: Missing && i == 0 ? missing : i
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
@inline Base.haskey(x::GroupedInvRefPool{T}, v::Missing) where {T} = T >: Missing
@inline Base.haskey(x::GroupedInvRefPool, v::Integer) = 1 <= v <= x.ngroups
Base.@propagate_inbounds function Base.getindex(x::GroupedInvRefPool{T}, v::Missing) where {T}
	@boundscheck T >: Missing
	return 0
end
Base.@propagate_inbounds function Base.getindex(x::GroupedInvRefPool, v::Integer)
	@boundscheck 1 <= v <= x.ngroups
	return v
end
@inline Base.get(x::GroupedInvRefPool{T}, v::Missing, default) where {T} = T >: Missing ? 0 : default
@inline Base.get(x::GroupedInvRefPool, v::Integer, default) = 1 <= v <= x.ngroups ? v : default
DataAPI.invrefpool(g::GroupedArray{T}) where {T} = GroupedInvRefPool{T}(g.ngroups)

export GroupedArray
end # module
