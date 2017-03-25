"A pure julia wrapper of R_ParseVector"
function parseVector{S<:Sxp}(st::Ptr{StrSxp}, sf::Ptr{S}=sexp(Const.NilValue))
    protect(st)
    protect(sf)
    status = Ref{Cint}()
    val = ccall((:R_ParseVector,libR),Ptr{UnknownSxp},
                (Ptr{StrSxp},Cint,Ptr{Cint},Ptr{UnknownSxp}),
                st,-1,status,sf)
    unprotect(2)
    val, status[]
end

"Get the R parser error msg for the previous parsing result."
function getParseErrorMsg()
    unsafe_string(cglobal((:R_ParseErrorMsg, libR), UInt8))
end

"Parse a string as an R expression, returning a Sxp pointer."
function rparse_p(st::Ptr{StrSxp})
    val, status = parseVector(st)
    if status == 2 || status == 3
        error("RCall.jl: ", getParseErrorMsg())
    elseif status == 4
        throw(EOFError())
    end
    sexp(val)
end
rparse_p(st::AbstractString) = rparse_p(sexp(st))
rparse_p(s::Symbol) = rparse_p(string(s))

"Parse a string as an R expression, returning an RObject."
rparse(st::AbstractString) = RObject(rparse_p(st))


"""
A pure julia wrapper of R_tryEval.
"""
function tryEval{S<:Sxp}(expr::Ptr{S}, env::Ptr{EnvSxp}=sexp(Const.GlobalEnv))
    disable_sigint() do
        status = Ref{Cint}()
        protect(expr)
        protect(env)
        val = ccall((:R_tryEval,libR),Ptr{UnknownSxp},(Ptr{S},Ptr{EnvSxp},Ref{Cint}),expr,env,status)
        unprotect(2)
        val, status[]
    end
end

"""
Evaluate an R symbol or language object (i.e. a function call) in an R
try/catch block, returning a Sxp pointer.
"""
function reval_p{S<:Sxp}(expr::Ptr{S}, env::Ptr{EnvSxp}, devices::Tuple{IO,IO,IO})
    val, status = tryEval(expr, env)
    stdio, warningio, errorio = devices
    Console.write_output(stdio)
    if status != 0
        Console.write_error(errorio)
        # in repl mode, error buffer is dumped to STDERR, so need to throw an error
        # to stop the evaluation
        throw(REvalutionError())
    else
        Console.write_error(warningio)
    end
    sexp(val)
end
reval_p{S<:Sxp}(expr::Ptr{S}, env::Ptr{EnvSxp}=sexp(Const.GlobalEnv)) =
    reval_p(expr, env, Console.default_devices)

"""
Evaluate an R expression array iteratively.
"""
function reval_p(expr::Ptr{ExprSxp}, env::Ptr{EnvSxp}, devices::Tuple{IO,IO,IO})
    local val
    protect(expr)
    protect(env)
    try
        for e in expr
            val = reval_p(e, env, devices)
        end
    finally
        unprotect(2)
    end
    # set .Last.value
    if env == Const.GlobalEnv.p
        set_last_value(val)
    end
    val
end
reval_p(expr::Ptr{ExprSxp}, env::Ptr{EnvSxp}=sexp(Const.GlobalEnv)) =
    reval_p(expr, env, Console.default_devices)

"""
Evaluate an R symbol or language object (i.e. a function call) in an R
try/catch block, returning an RObject.
"""
reval(r::RObject, env=Const.GlobalEnv) = RObject(reval_p(sexp(r), sexp(env)))
reval(str::Union{AbstractString,Symbol}, env=Const.GlobalEnv) = RObject(reval_p(rparse_p(str), sexp(env)))