# This code is taken from DataFrames.jl/src/other/utils.jl

if VERSION >= v"1.3"
    using Base.Threads: @spawn
else
    # This is the definition of @async in Base
    macro spawn(expr)
        thunk = esc(:(()->($expr)))
        var = esc(Base.sync_varname)
        quote
            local task = Task($thunk)
            if $(Expr(:isdefined, var))
                push!($var, task)
            end
            schedule(task)
        end
    end
end
if VERSION >= v"1.4"
    function _spawn_for_chunks_helper(iter, lbody, basesize)
        lidx = iter.args[1]
        range = iter.args[2]
        quote
            let x = $(esc(range)), basesize = $(esc(basesize))
                @assert firstindex(x) == 1

                nt = Threads.nthreads()
                len = length(x)
                if nt > 1 && len > basesize
                    tasks = [Threads.@spawn begin
                                 for i in p
                                     local $(esc(lidx)) = @inbounds x[i]
                                     $(esc(lbody))
                                 end
                             end
                             for p in split_indices(len, basesize)]
                    foreach(wait, tasks)
                else
                    for i in eachindex(x)
                        local $(esc(lidx)) = @inbounds x[i]
                        $(esc(lbody))
                    end
                end
            end
            nothing
        end
    end
else
    function _spawn_for_chunks_helper(iter, lbody, basesize)
        lidx = iter.args[1]
        range = iter.args[2]
        quote
            let x = $(esc(range))
                for i in eachindex(x)
                    local $(esc(lidx)) = @inbounds x[i]
                    $(esc(lbody))
                end
            end
            nothing
        end
    end
end

"""
    @spawn_for_chunks basesize for i in range ... end
Parallelize a `for` loop by spawning separate tasks
iterating each over a chunk of at least `basesize` elements
in `range`.
A number of task higher than `Threads.nthreads()` may be spawned,
since that can allow for a more efficient load balancing in case
some threads are busy (nested parallelism).
"""
macro spawn_for_chunks(basesize, ex)
    if !(isa(ex, Expr) && ex.head === :for)
        throw(ArgumentError("@spawn_for_chunks requires a `for` loop expression"))
    end
    if !(ex.args[1] isa Expr && ex.args[1].head === :(=))
        throw(ArgumentError("nested outer loops are not currently supported by @spawn_for_chunks"))
    end
    return _spawn_for_chunks_helper(ex.args[1], ex.args[2], basesize)
end
