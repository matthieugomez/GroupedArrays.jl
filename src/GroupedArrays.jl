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

Base.@propagate_inbounds function Base.getindex(g::GroupedArray, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
	x == 0 ? missing : x
end
Base.@propagate_inbounds function Base.setindex!(g::GroupedArray{T}, x::Missing,  i::Number) where T >: Missing
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
	groups = Vector{Int}(undef, prod(s))
	ngroups, rhashes, gslots, sorted = row_group_slots(map(vec, args), Val(false), groups, !coalesce, false)
	if !coalesce & any((eltype(x) >: Missing for x in args))
		T = Union{Int, Missing}
	else
		T = Int
	end
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
Base.size(x::GroupedRefPool{T}) where T = (x.ngroups + T >: Missing,)
Base.axes(x::GroupedRefPool{T}) where T = ((1-(T >: Missing)):x.ngroups,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(x::GroupedRefPool{T}, i::Integer) where T
    @boundscheck checkbounds(x, i)
    if T >: Missing && (i==0)
    	return missing
    else
    	i
    end
end
Base.allunique(x::GroupedRefPool) = true

DataAPI.refpool(g::GroupedArray{T}) where {T} = GroupedRefPool{T}(g.ngroups)
# invrefpool is such that invrefpool[refpool[x]] = x. Basically, it gives the index in the pool (so the ref level) corresponding to each element of refpool
# so it should be missing -> 0 and i -> i for 1 ≤ i ≤ g.ngroups
struct GroupedInvRefPool{T}
	ngroups::Int
end
@inline Base.haskey(x::GroupedInvRefPool{T}, v::Missing) where {T} = T >: Missing
@inline Base.haskey(x::GroupedInvRefPool, v::Integer) = (v >= 1) & (v <= x.ngroups)
@inline function Base.getindex(x::GroupedInvRefPool{T}, v::Missing) where {T}
	@boundscheck T >: Missing
	0
end
@inline function Base.getindex(x::GroupedInvRefPool, v::Integer)
	@boundscheck (v >= 1) & (v <= x.ngroups)
	v
end
@inline Base.get(x::GroupedInvRefPool{T}, v::Missing, default) where {T} = (T >: Missing) ? 0 : default
@inline Base.get(x::GroupedInvRefPool, v::Integer, default) = ((v >= 1) & (v <= x.ngroups)) ? v : default
DataAPI.invrefpool(g::GroupedArray{T}) where {T} = GroupedInvRefPool{T}(g.ngroups)




export GroupedArray
end # module
