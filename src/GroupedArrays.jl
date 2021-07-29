module GroupedArrays

using DataAPI

mutable struct GroupedArray{T <: Integer, N} <: AbstractArray{Union{T, Missing}, N}
	refs::Array{T, N}   # refs must be between 0 and n. 0 means missing
	n::Int              # Number of potential values (= maximum(refs))
end
Base.size(g::GroupedArray) = size(g.refs)
Base.axes(g::GroupedArray) = axes(g.refs)
Base.IndexStyle(g::GroupedArray) = Base.IndexLinear()
Base.LinearIndices(g::GroupedArray) = axes(g.refs, 1)

Base.@propagate_inbounds function Base.getindex(g::GroupedArray, i::Number) where {R}
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
	x > g.n && (g.n = x)
	@inbounds g.refs[i] = x
end

# Constructor
GroupedArray(xs...) = GroupedArray{Int}(xs...)

function GroupedArray{R}(g::GroupedArray{T, N}) where {R, T, N}
	return GroupedArray{R, N}(convert(Array{R, N}, g.refs), g.n)

end

function GroupedArray{R}(xs::AbstractArray) where {R}
	refarray = DataAPI.refarray(xs)
	refpool = DataAPI.refpool(xs)
	if refpool !== nothing
		# When invrefpool is defined, values are necessarily unique
		if DataAPI.invrefpool(xs) !== nothing || allunique(refpool)
			return _group(refarray, refpool, R)
		end
	end
	return _group(xs, R)
end


function _group(xs::AbstractArray{<:Union{Integer, Missing}}, R::Type)
	min, max = minimum(skipmissing(xs)), maximum(skipmissing(xs))
	refs = Array{R}(undef, size(xs))
	invpool = zeros(R, max - min + 1)
	n = zero(R)
	i = 0
	@inbounds for x in xs
		i += 1
		if x === missing
			refs[i] = zero(R)
		else
			lbl = invpool[x - min + 1]
			if !iszero(lbl)
				refs[i] = lbl
			else
				n += 1
				invpool[x - min + 1] = n
				refs[i] = n
			end
		end
	end
	return GroupedArray{R, ndims(refs)}(refs, n)
end

function _group(xs, R::Type)
	refs = Array{R}(undef, size(xs))
	invpool = Dict{eltype(xs), R}()
	n = zero(R)
	i = 0
	@inbounds for x in xs
		i += 1
		if x === missing
			refs[i] = zero(R)
		else
			lbl = get(invpool, x, zero(R))
			if !iszero(lbl)
				refs[i] = lbl
			else
				n += 1
				refs[i] = n
				invpool[x] = n
			end
		end
	end
	return GroupedArray{R, ndims(xs)}(refs, n)
end


function _group(ra, rp, R::Type)
	refs = Array{R}(undef, size(ra))
	hashes = Vector{R}(undef, length(rp))
	firp = firstindex(rp)
	n = 0
	@inbounds for i in eachindex(hashes)
		if rp[i+firp-1] === missing
			hashes[i] = 0
		else
			n += 1
			hashes[i] = n
		end
	end
	fira = firstindex(ra)
	@inbounds for i in eachindex(refs)
		refs[i] = hashes[ra[i+fira-1]-firp+1]
	end
	return GroupedArray{R, ndims(refs)}(refs, n)
end

function GroupedArray{R}(args...) where {R}
	g1 = deepcopy(GroupedArray{UInt32}(args[1]))
	for j = 2:length(args)
		gj = GroupedArray{UInt32}(args[j])
		size(g1) == size(gj) || throw(DimensionMismatch(
            "cannot match array of size $(size(g1)) with array of size $(size(gj))"))
		combine!(g1, gj)
	end
	factorize!(g1, R)
end

function combine!(g1::GroupedArray, g2::GroupedArray)
	@inbounds for i in eachindex(g1.refs, g2.refs)
		# if previous one is missing or this one is missing, set to missing
		g1.refs[i] = (g1.refs[i] == 0 || g2.refs[i] == 0) ? 0 : g1.refs[i] + (g2.refs[i] - 1) * g1.n
	end
	g1.n = g1.n * g2.n
	return g1
end

function factorize!(g::GroupedArray, R)
	#relabel refs
	refs = convert(Array{R, ndims(g)}, g.refs)
	invpool = zeros(R, g.n)
	n = zero(R)
	i = 0
	@inbounds for x in refs
	    i += 1
	    if !iszero(x)
	        lbl = invpool[x]
	        if !iszero(lbl)
	            refs[i] = lbl
	        else
	            n += 1
	            refs[i] = n
	            invpool[x] = n
	        end
	    end
	end
	return GroupedArray{R, ndims(g)}(refs, n)
end




# Data API
DataAPI.refarray(g::GroupedArray) = g.refs
DataAPI.levels(g::GroupedArray) = 1:g.n
Base.@propagate_inbounds function DataAPI.refvalue(g::GroupedArray, ref::Integer)
	ref > 0 ? ref : missing
end
# refpool is such that refpool[refarray[i]] = x
struct GroupedRefPool{T} <: AbstractVector{Union{T, Missing}}
	n::Int
end
Base.size(x::GroupedRefPool{T}) where {T} = (x.n + 1,)
Base.axes(x::GroupedRefPool{T}) where {T} = (0:x.n,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(x::GroupedRefPool, i::Integer)
    @boundscheck checkbounds(x, i)
    i > 0 ? i : missing
end
Base.LinearIndices(x::GroupedRefPool) = axes(x, 1)
Base.allunique(x::GroupedRefPool) = true
DataAPI.refpool(g::GroupedArray{T}) where {T} = GroupedRefPool{T}(g.n)
# invrefpool is such that invrefpool[refpool[x]] = x. Basically, it gives the index in the pool (so the ref level) corresponding to each element of refpool
# so it should be missing -> 0 and i -> i for 1 ≤ i ≤ g.n
struct GroupedInvRefPool{T}
	n::Int
end
@inline Base.haskey(x::GroupedInvRefPool, v::Missing) = true
@inline Base.haskey(x::GroupedInvRefPool, v::Integer) = (v >= 1) & (v <= x.n)
@inline Base.getindex(x::GroupedInvRefPool{T}, v::Missing) where {T} = zero(T)
@inline function Base.getindex(x::GroupedInvRefPool, v::Integer)
	@boundscheck (v >= 1) & (v <= x.n)
	v
end
@inline Base.get(x::GroupedInvRefPool{T}, v::Missing, default) where {T} = zero(T)
@inline function Base.get(x::GroupedInvRefPool{T}, v::Integer, default) where {T}
	if (v >= 1) & (v <= x.n)
		v
	else
		default
	end
end
DataAPI.invrefpool(g::GroupedArray{T}) where {T} = GroupedInvRefPool{T}(g.n)




export GroupedArray
end # module
