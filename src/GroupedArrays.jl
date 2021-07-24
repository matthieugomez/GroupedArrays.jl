module GroupedArrays

using DataAPI

mutable struct GroupedArray{T, N} <: AbstractArray{T, N}
	refs::Array{UInt32, N}   # refs must be between 0 and n. 0 means missing
	n::Int              # Number of potential values (= maximum(refs))
end
Base.size(g::GroupedArray) = size(g.refs)
Base.axes(g::GroupedArray) = axes(g.refs)
Base.IndexStyle(g::GroupedArray) = Base.IndexLinear()
Base.LinearIndices(x::GroupedRefPool) = axes(g.refs, 1)
Base.@propagate_inbounds function Base.getindex(g::GroupedArray{Int}, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
	Int(x)
end
Base.@propagate_inbounds function Base.getindex(g::GroupedArray{V, Union{Int, Missing}}, i::Number) where {V}
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
	x > 0 ? Int(x) : missing
end


# Constructor
GroupedArray(xs::GroupedArray) = xs
function GroupedArray(xs::AbstractArray)
	_group(DataAPI.refarray(xs), DataAPI.refpool(xs))
end
function _group(xs, ::Nothing)
	refs = Array{DefaultRefType}(undef, size(xs))
	invpool = Dict{eltype(xs), UInt32}()
	has_missing = false
	n = UInt32(0)
	i = UInt32(0)
	@inbounds for x in xs
		i += 1
		if x === missing
			refs[i] = 0
			has_missing = true
		else
			lbl = get(invpool, x, UInt32(0))
			if !iszero(lbl)
				refs[i] = lbl
			else
				n += 1
				refs[i] = n
				invpool[x] = n
			end
		end
	end
	return GroupedArray{has_missing ? Union{Int, Missing} : Int, ndims(xs)}(refs, n)
end

function _group(ra, rp)
	refs = Array{DefaultRefType}(undef, size(ra))
	hashes = Array{DefaultRefType}(undef, length(rp))
	firp = firstindex(rp)
	n = 0
	has_missing = false
	for i in eachindex(hashes)
		if rp[i+firp-1] === missing
			hashes[i] = 0
			has_missing = true
		else
			n += 1
			hashes[i] = n
		end
	end
	fira = firstindex(ra)
	@inbounds for i in eachindex(refs)
		refs[i] = hashes[ra[i+fira-1]-firp+1]
	end
	return GroupedArray{has_missing ? Union{Int, Missing} : Int, ndims(refs)}(refs, n)
end

function GroupedArray(args...)
	g1 = deepcopy(GroupedArray(args[1]))
	for j = 2:length(args)
		gj = GroupedArray(args[j])
		size(g1) == size(gj) || throw(DimensionMismatch(
            "cannot match array of size $(size(g1)) with array of size $(size(gj))"))
		combine!(g1, gj)
	end
	factorize!(g1)
end

function combine!(g1::GroupedArray, g2::GroupedArray)
	@inbounds for i in eachindex(g1.refs, g2.refs)
		# if previous one is missing or this one is missing, set to missing
		g1.refs[i] = (g1.refs[i] == 0 || g2.refs[i] == 0) ? 0 : g1.refs[i] + (g2.refs[i] - 1) * g1.n
	end
	g1.n = g1.n * g2.n
	return g1
end

# An in-place version of _group() that relabels the refs
function factorize!(g::GroupedArray{T, N}) where {T, N}
    refs = g.refs
    invpool = zeros(UInt32, g.n)
    n = UInt32(0)
    i = UInt32(0)
    @inbounds for x in xs
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
    return GroupedArray{T, N}(refs, n)
end



# Data API
struct GroupedRefPool{T} <: AbstractVector{T}
	n::Int
end
Base.size(x::GroupedRefPool{T}) where {T} = (x.n + (T >: Missing),)
Base.axes(x::GroupedRefPool{T}) where {T} = ((T >: Missing ? 0 : 1):x.n,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(x::GroupedRefPool, i::Int)
    @boundscheck checkbounds(x, i)
    i > 0 ? Int(i) : missing
end
Base.LinearIndices(x::GroupedRefPool) = axes(x, 1)
DataAPI.refarray(g::GroupedArray) = g.refs
DataAPI.refpool(g::GroupedArray{V, R, N}) = GroupedRefPool{R}(g.n)
@inline DataAPI.refvalue(g::GroupedArray, i::Integer)
	@boundscheck checkbounds(x, i)
	i > 0 ? Int(x) : missing
end

export GroupedArray
end # module
