# logic for default rcopy

"""
`rcopy(r)` copies the contents of an R object into a corresponding canonical Julia type.
"""
rcopy(r::RObject) = rcopy(r.p)

# Fallback
rcopy{S<:Sxp}(::Type{Any}, s::Ptr{S}) = rcopy(s)

# NilSxp
rcopy(::Ptr{NilSxp}) = nothing

# SymSxp and CharSxp
rcopy(s::SymSxpPtr) = rcopy(Symbol,s)
rcopy(s::CharSxpPtr) = rcopy(String,s)

# StrSxp
function rcopy(s::StrSxpPtr)
    if anyna(s)
        rcopy(NullableArray,s)
    elseif length(s) == 1
        rcopy(String,s)
    else
        rcopy(Array{String},s)
    end
end

# IntSxp, RealSxp, CplxSxp, LglSxp
function rcopy(s::IntSxpPtr)
    if isFactor(s)
        rcopy(PooledDataArray,s)
    elseif anyna(s)
        rcopy(DataArray{Float64},s)
    elseif length(s) == 1
        rcopy(Cint,s)
    else
        rcopy(Array,s)
    end
end
function rcopy(s::RealSxpPtr)
    if anyna(s)
        rcopy(DataArray{Float64},s)
    elseif length(s) == 1
        rcopy(Float64,s)
    else
        rcopy(Array{Float64},s)
    end
end
function rcopy(s::CplxSxpPtr)
    if anyna(s)
        rcopy(DataArray{Complex128},s)
    elseif length(s) == 1
        rcopy(Complex128,s)
    else
        rcopy(Array{Complex128},s)
    end
end
function rcopy(s::LglSxpPtr)
    if anyna(s)
        rcopy(DataArray{Bool},s)
    elseif length(s) == 1
        rcopy(Bool,s)
    else
        rcopy(BitArray,s)
    end
end

# VecSxp
function rcopy(s::VecSxpPtr)
    if isFrame(s)
        rcopy(DataFrame,s)
    elseif isnull(getnames(s))
        rcopy(Array{Any},s)
    else
        rcopy(Dict{Symbol,Any},s)
    end
end

# FunctionSxp
rcopy(s::FunctionSxpPtr) = rcopy(Function,s)

# TODO
# rcopy(l::LangSxpPtr) = l
# rcopy(r::RObject{LangSxp}) = r

# logic of default sexp

"""
`sexp(x)` converts a Julia object `x` to a pointer to a corresponding Sxp Object.
"""

RObject(s) = RObject(sexp(s))

# nothing
sexp(::Void) = sexp(Const.NilValue)

# symbol
sexp(s::Symbol) = sexp(SymSxp,s)

# string and string array
sexp{S<:AbstractString}(a::AbstractArray{S}) = sexp(StrSxp,a)
sexp(st::AbstractString) = sexp(StrSxp,st)

# DataFrames
sexp(d::AbstractDataFrame) = sexp(VecSxp, d)

# PooledDataArray
sexp(a::PooledDataArray) = sexp(IntSxp,a)
sexp{S<:AbstractString}(a::PooledDataArray{S}) = sexp(IntSxp,a)

# number
for (J,S) in ((:Integer,:IntSxp),
                 (:Real, :RealSxp),
                 (:Complex, :CplxSxp),
                 (:Bool, :LglSxp))
    @eval begin
        sexp{T<:$J}(a::AbstractArray{T}) = sexp($S,a)
        sexp{T<:$J}(a::DataArray{T}) = sexp($S,a)
        sexp(v::$J) = sexp($S,v)
    end
end

# Fallback: convert abstractArray to VecSxp (R list)
sexp(a::AbstractArray) = sexp(VecSxp,a)

# associative
sexp(d::Associative) = sexp(VecSxp,d)

# Nullable
for (J,S) in ((:Integer,:IntSxp),
                 (:Real, :RealSxp),
                 (:Complex, :CplxSxp),
                 (:Bool, :LglSxp),
                 (:AbstractString, :StrSxp))
    @eval begin
        sexp{T<:$J}(x::Nullable{T}) = sexp($S, x)
        sexp{T<:$J}(v::NullableArray{T}) = sexp($S, v)
    end
end
for typ in [:NullableCategoricalArray, :CategoricalArray]
    @eval sexp(v::$typ) = sexp(IntSxp, v)
end
