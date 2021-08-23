function _precompile_()
    Base.precompile(Tuple{typeof(GroupedArray),Array{Int,1}})
    Base.precompile(Tuple{typeof(GroupedArray),Array{Union{Int, Missing},1}})
    Base.precompile(Tuple{typeof(GroupedArray),Array{String,1}})
    Base.precompile(Tuple{typeof(GroupedArray),Array{Union{String, Missing},1}})
end
