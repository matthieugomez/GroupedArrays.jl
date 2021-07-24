module GroupedArrays

using DataAPI

mutable struct GroupedArray{T <: Union{Integer, Missing}, N} <: AbstractArray{T, N}
	refs::Array{T, N}   # refs must be between 0 and n. 0 means missing
	n::Int              # Number of potential values (= maximum(refs))
end
Base.size(g::GroupedArray) = size(g.refs)
Base.axes(g::GroupedArray) = axes(g.refs)
Base.IndexStyle(g::GroupedArray) = Base.IndexLinear()
Base.LinearIndices(x::GroupedArray) = axes(g.refs, 1)
Base.@propagate_inbounds function Base.getindex(g::GroupedArray{<: Integer}, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
end
Base.@propagate_inbounds function Base.getindex(g::GroupedArray, i::Number)
	@boundscheck checkbounds(g, i)
	@inbounds x = g.refs[i]
	x > 0 ? x : missing
end


Base.@propagate_inbounds function Base.setindex!(g::GroupedArray{<: Integer}, x::Number, i::Number)
	@boundscheck checkbounds(g, i)
	x <= 0 && throw(ArgumentError("The number x must be positive"))
	x > g.n && (g.n = x)
	@inbounds g.refs[i] = x
end
Base.@propagate_inbounds function Base.setindex!(g::GroupedArray{Union{<:Integer, Missing}}, x::Missing,  i::Number)
	@boundscheck checkbounds(g, i)
	g[i] = 0
end
Base.@propagate_inbounds function Base.setindex!(g::GroupedArray, x::Number,  i::Number)
	@boundscheck checkbounds(g, i)
	x <= 0 && throw(ArgumentError("The number x must be positive"))
	x > g.n && (g.n = x)
	@inbounds g.refs[i] = x
end

# Constructor
GroupedArray(xs...) = GroupedArray{Int}(xs...)


function GroupedArray{R}(xs::GroupedArray{V, N}) where {R, V, N}
	GroupedArray{R, N}(convert(Array{r, N}, xs.refs), r.n)
end

function GroupedArray{R}(xs::AbstractArray) where {R}
	_group(DataAPI.refarray(xs), DataAPI.refpool(xs), R)
end

function _group(xs, ::Nothing, r::Type)
	refs = Array{r}(undef, size(xs))
	invpool = Dict{eltype(xs), r}()
	has_missing = false
	n = r(0)
	i = r(0)
	@inbounds for x in xs
		i += 1
		if x === missing
			refs[i] = 0
			has_missing = true
		else
			lbl = get(invpool, x, r(0))
			if !iszero(lbl)
				refs[i] = lbl
			else
				n += 1
				refs[i] = n
				invpool[x] = n
			end
		end
	end
	return GroupedArray{has_missing ? Union{r, Missing} : r, ndims(xs)}(refs, n)
end

function _group(ra, rp, r::Type)
	refs = Array{r}(undef, size(ra))
	hashes = Array{r}(undef, length(rp))
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
	return GroupedArray{has_missing ? Union{r, Missing} : r, ndims(refs)}(refs, n)
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

# An in-place version of _group() that relabels the refs
function factorize!(g::GroupedArray{T, N}, r::Type) where {T, N}
    refs = convert(Array{r, N}, g.refs)
    invpool = zeros(r, g.n)
    n = zero(r)
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
    return GroupedArray{r, N}(refs, n)
end



# Data API
DataAPI.refarray(g::GroupedArray) = g.refs
struct GroupedRefPool{T} <: AbstractVector{T}
	n::Int
end
Base.size(x::GroupedRefPool{T}) where {T} = (x.n + (T >: Missing),)
Base.axes(x::GroupedRefPool{T}) where {T} = ((T >: Missing ? 0 : 1):x.n,)
Base.IndexStyle(::Type{<: GroupedRefPool}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(x::GroupedRefPool, i::Int)
    @boundscheck checkbounds(x, i)
    i > 0 ? i : missing
end
Base.LinearIndices(x::GroupedRefPool) = axes(x, 1)
DataAPI.refpool(g::GroupedArray{T}) where {T} = GroupedRefPool{T}(g.n)
Base.@propagate_inbounds function DataAPI.refvalue(g::GroupedArray, i::Integer)
	@boundscheck checkbounds(x, i)
	i > 0 ? x : missing
end

export GroupedArray
end # module
