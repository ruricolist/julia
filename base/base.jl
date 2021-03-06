typealias Callable Union(Function,DataType)

const Bottom = Union()

# constructors for Core types in boot.jl
call(T::Type{BoundsError}) = Core.call(T)
call(T::Type{BoundsError}, args...) = Core.call(T, args...)
call(T::Type{DivideError}) = Core.call(T)
call(T::Type{DomainError}) = Core.call(T)
call(T::Type{OverflowError}) = Core.call(T)
call(T::Type{InexactError}) = Core.call(T)
call(T::Type{OutOfMemoryError}) = Core.call(T)
call(T::Type{StackOverflowError}) = Core.call(T)
call(T::Type{UndefRefError}) = Core.call(T)
call(T::Type{UndefVarError}, var::Symbol) = Core.call(T, var)
call(T::Type{InterruptException}) = Core.call(T)
call(T::Type{SymbolNode}, name::Symbol, t::ANY) = Core.call(T, name, t)
call(T::Type{GlobalRef}, modu, name::Symbol) = Core.call(T, modu, name)
call(T::Type{ASCIIString}, d::Array{UInt8,1}) = Core.call(T, d)
call(T::Type{UTF8String}, d::Array{UInt8,1}) = Core.call(T, d)
call(T::Type{TypeVar}, args...) = Core.call(T, args...)
call(T::Type{TypeConstructor}, args...) = Core.call(T, args...)
call(T::Type{Expr}, args::ANY...) = _expr(args...)
call(T::Type{LineNumberNode}, n::Int) = Core.call(T, n)
call(T::Type{LabelNode}, n::Int) = Core.call(T, n)
call(T::Type{GotoNode}, n::Int) = Core.call(T, n)
call(T::Type{QuoteNode}, x::ANY) = Core.call(T, x)
call(T::Type{NewvarNode}, s::Symbol) = Core.call(T, s)
call(T::Type{TopNode}, s::Symbol) = Core.call(T, s)
call(T::Type{Module}, args...) = Core.call(T, args...)
call(T::Type{Task}, f::ANY) = Core.call(T, f)
call(T::Type{GenSym}, n::Int) = Core.call(T, n)
call(T::Type{WeakRef}) = Core.call(T)
call(T::Type{WeakRef}, v::ANY) = Core.call(T, v)

call{T}(::Type{T}, args...) = convert(T, args...)::T

convert{T}(::Type{T}, x::T) = x

convert(::Type{Tuple{}}, ::Tuple{}) = ()
convert(::Type{Tuple}, x::Tuple) = x
convert{T}(::Type{Tuple{Vararg{T}}}, x::Tuple) = cnvt_all(T, x...)
cnvt_all(T) = ()
cnvt_all(T, x, rest...) = tuple(convert(T,x), cnvt_all(T, rest...)...)

stagedfunction tuple_type_head{T<:Tuple}(::Type{T})
    T.parameters[1]
end

isvarargtype(t::ANY) = isa(t,DataType)&&is((t::DataType).name,Vararg.name)
isvatuple(t::DataType) = (n = length(t.parameters); n > 0 && isvarargtype(t.parameters[n]))
unwrapva(t::ANY) = isvarargtype(t) ? t.parameters[1] : t

stagedfunction tuple_type_tail{T<:Tuple}(::Type{T})
    if isvatuple(T) && length(T.parameters) == 1
        return T
    end
    Tuple{argtail(T.parameters...)...}
end

argtail(x, rest...) = rest
tail(x::Tuple) = argtail(x...)

convert{T<:Tuple{Any,Vararg{Any}}}(::Type{T}, x::Tuple{Any, Vararg{Any}}) =
    tuple(convert(tuple_type_head(T),x[1]), convert(tuple_type_tail(T), tail(x))...)

oftype(x,c) = convert(typeof(x),c)

unsigned(x::Int) = reinterpret(UInt, x)
signed(x::UInt) = reinterpret(Int, x)

# conversions used by ccall
ptr_arg_cconvert{T}(::Type{Ptr{T}}, x) = cconvert(T, x)
ptr_arg_unsafe_convert{T}(::Type{Ptr{T}}, x) = unsafe_convert(T, x)
ptr_arg_unsafe_convert(::Type{Ptr{Void}}, x) = x

cconvert(T::Type, x) = convert(T, x) # do the conversion eagerly in most cases
cconvert{P<:Ptr}(::Type{P}, x) = x # but defer the conversion to Ptr to unsafe_convert
unsafe_convert{T}(::Type{T}, x::T) = x # unsafe_convert (like convert) defaults to assuming the convert occurred
unsafe_convert{P<:Ptr}(::Type{P}, x::Ptr) = convert(P, x)

reinterpret{T,S}(::Type{T}, x::S) = box(T,unbox(S,x))

sizeof(x) = Core.sizeof(x)

abstract IO

type ErrorException <: Exception
    msg::AbstractString
end

type SystemError <: Exception
    prefix::AbstractString
    errnum::Int32
    SystemError(p::AbstractString, e::Integer) = new(p, e)
    SystemError(p::AbstractString) = new(p, Libc.errno())
end

type TypeError <: Exception
    func::Symbol
    context::AbstractString
    expected::Type
    got
end

type ParseError <: Exception
    msg::AbstractString
end

type ArgumentError <: Exception
    msg::AbstractString
end

#type UnboundError <: Exception
#    var::Symbol
#end

type KeyError <: Exception
    key
end

type LoadError <: Exception
    file::AbstractString
    line::Int
    error
end

type MethodError <: Exception
    f
    args
end

type EOFError <: Exception end

type DimensionMismatch <: Exception
    msg::AbstractString
end
DimensionMismatch() = DimensionMismatch("")

type AssertionError <: Exception
    msg::AbstractString

    AssertionError() = new("")
    AssertionError(msg) = new(msg)
end

# For passing constants through type inference
immutable Val{T}
end

ccall(:jl_get_system_hooks, Void, ())


# index colon
type Colon
end
const (:) = Colon()

==(w::WeakRef, v::WeakRef) = isequal(w.value, v.value)
==(w::WeakRef, v) = isequal(w.value, v)
==(w, v::WeakRef) = isequal(w, v.value)

function finalizer(o::ANY, f::Union(Function,Ptr))
    if isimmutable(o)
        error("objects of type ", typeof(o), " cannot be finalized")
    end
    ccall(:jl_gc_add_finalizer, Void, (Any,Any), o, f)
end

finalize(o::ANY) = ccall(:jl_finalize, Void, (Any,), o)

gc(full::Bool=true) = ccall(:jl_gc_collect, Void, (Cint,), full)
gc_enable() = Bool(ccall(:jl_gc_enable, Cint, ()))
gc_disable() = Bool(ccall(:jl_gc_disable, Cint, ()))

bytestring(str::ByteString) = str

identity(x) = x

function append_any(xs...)
    # used by apply() and quote
    # must be a separate function from append(), since apply() needs this
    # exact function.
    out = Array(Any, 4)
    l = 4
    i = 1
    for x in xs
        for y in x
            if i > l
                ccall(:jl_array_grow_end, Void, (Any, UInt), out, 16)
                l += 16
            end
            arrayset(out, y, i)
            i += 1
        end
    end
    ccall(:jl_array_del_end, Void, (Any, UInt), out, l-i+1)
    out
end

# used by { } syntax
function cell_1d(xs::ANY...)
    n = length(xs)
    a = Array(Any,n)
    for i=1:n
        arrayset(a,xs[i],i)
    end
    a
end

function cell_2d(nr, nc, xs::ANY...)
    a = Array(Any,nr,nc)
    for i=1:(nr*nc)
        arrayset(a,xs[i],i)
    end
    a
end

# simple Array{Any} operations needed for bootstrap
setindex!(A::Array{Any}, x::ANY, i::Real) = arrayset(A, x, to_index(i))

function length_checked_equal(args...)
    n = length(args[1])
    for i=2:length(args)
        if length(args[i]) != n
            error("argument dimensions must match")
        end
    end
    n
end

map(f::Function, a::Array{Any,1}) = Any[ f(a[i]) for i=1:length(a) ]

function precompile(f::ANY, args::Tuple)
    if isa(f,DataType)
        args = tuple(Type{f}, args...)
        f = f.name.module.call
    end
    if isgeneric(f)
        ccall(:jl_compile_hint, Void, (Any, Any), f, Tuple{args...})
    end
end

esc(e::ANY) = Expr(:escape, e)

macro boundscheck(yesno,blk)
    # hack: use this syntax since it avoids introducing line numbers
    :($(Expr(:boundscheck,yesno));
      $(esc(blk));
      $(Expr(:boundscheck,:pop)))
end

macro inbounds(blk)
    :(@boundscheck false $(esc(blk)))
end

macro label(name::Symbol)
    Expr(:symboliclabel, name)
end

macro goto(name::Symbol)
    Expr(:symbolicgoto, name)
end

call{T,N}(::Type{Array{T}}, d::NTuple{N,Int}) =
    ccall(:jl_new_array, Array{T,N}, (Any,Any), Array{T,N}, d)
call{T}(::Type{Array{T}}, d::Integer...) = Array{T}(convert(Tuple{Vararg{Int}}, d))

call{T}(::Type{Array{T}}, m::Integer) =
    ccall(:jl_alloc_array_1d, Array{T,1}, (Any,Int), Array{T,1}, m)
call{T}(::Type{Array{T}}, m::Integer, n::Integer) =
    ccall(:jl_alloc_array_2d, Array{T,2}, (Any,Int,Int), Array{T,2}, m, n)
call{T}(::Type{Array{T}}, m::Integer, n::Integer, o::Integer) =
    ccall(:jl_alloc_array_3d, Array{T,3}, (Any,Int,Int,Int), Array{T,3}, m, n, o)

# TODO: possibly turn these into deprecations
Array{T,N}(::Type{T}, d::NTuple{N,Int}) = Array{T}(d)
Array{T}(::Type{T}, d::Integer...)      = Array{T}(convert(Tuple{Vararg{Int}}, d))
Array{T}(::Type{T}, m::Integer)                       = Array{T}(m)
Array{T}(::Type{T}, m::Integer,n::Integer)            = Array{T}(m,n)
Array{T}(::Type{T}, m::Integer,n::Integer,o::Integer) = Array{T}(m,n,o)

# SimpleVector

function getindex(v::SimpleVector, i::Int)
    if !(1 <= i <= length(v))
        throw(BoundsError())
    end
    unsafe_load(convert(Ptr{Any},data_pointer_from_objref(v)) + i*sizeof(Ptr))
end

length(v::SimpleVector) = v.length
endof(v::SimpleVector) = v.length
start(v::SimpleVector) = 1
next(v::SimpleVector,i) = (v[i],i+1)
done(v::SimpleVector,i) = (i > v.length)
isempty(v::SimpleVector) = (v.length == 0)

map(f, v::SimpleVector) = Any[ f(v[i]) for i = 1:length(v) ]

getindex(v::SimpleVector, I::AbstractArray) = Any[ v[i] for i in I ]

immutable Nullable{T}
    isnull::Bool
    value::T

    Nullable() = new(true)
    Nullable(value::T) = new(false, value)
end
