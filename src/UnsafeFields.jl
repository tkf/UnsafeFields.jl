module UnsafeFields

export unsafe_getfield, unsafe_setfield!

if !@isdefined(ismutabletype)
    function ismutabletype(@nospecialize(t::Type))
        if isconcretetype(t)
            return t.mutable
        else
            return false
        end
    end
end

ispointerfield(::Type{T}) where {T} = !Base.datatype_pointerfree(Some{T})

@generated function fieldindex(::Type{T}, ::Val{field}) where {T,field}
    field isa Symbol || return :(error("`field` must be a symbol; given: $field"))
    return findfirst(n -> n === field, fieldnames(T))
end

@generated allocate_singleton_ref(::Type{T}) where {T} = Ref{Any}(T.instance)

@inline pointer_from_singleton(::T) where {T} = pointer_from_singleton_type(T)
@inline function pointer_from_singleton_type(::Type{T}) where {T}
    refptr = pointer_from_objref(allocate_singleton_ref(T))
    return unsafe_load(Ptr{Ptr{Cvoid}}(refptr))
end

"""
    heap_pointer(v) -> (handle, ptr::UInt)

Hopefully heap-allocate `v`, return a `handle` that can be passed to
`GC.@preserve` and the `UInt` representation of the pointer.
"""
@inline function heap_pointer(v::T) where {T}
    if ismutabletype(T)
        # Is this enough to heap-allocate `v`?
        handle = Some(v)
        return (handle, UInt(pointer_from_objref(v)))
    elseif Base.issingletontype(T)
        # Use globally rooted heap-allocated singleton as an optimization:
        return (nothing, UInt(pointer_from_singleton(v)))
    else
        # Is there a way to avoid heap-allocating `Ref{Any}`?
        handle = Ref{Any}(v)
        GC.@preserve handle begin
            vptr = unsafe_load(Ptr{Ptr{Cvoid}}(pointer_from_objref(handle)))
        end
        return (handle, UInt(vptr))
    end
end

"""
    unsafe_setfield!([unsafe_store!,] ptr::Ptr{T}, v::T)

Store the value `v` to the interior field of an immutable struct specified by
pointer `ptr`.  The caller is responsible for rooting the object owning `ptr`.
"""
unsafe_setfield!
@inline unsafe_setfield!(ptr::Ptr, v) = unsafe_setfield!(unsafe_store!, ptr, v)
@inline function unsafe_setfield!(unsafe_store!, ptr::Ptr{T}, v::T) where {T}
    if ispointerfield(T)
        handle, vint = heap_pointer(v)
        GC.@preserve handle begin
            unsafe_store!(Ptr{typeof(vint)}(ptr), vint)
        end
    elseif T isa Union  # Union of immutables; store the type tag
        u = Some{T}(v)
        GC.@preserve u begin
            unsafe_store!(Ptr{Some{T}}(ptr), u)
        end
    else
        @assert !ismutabletype(T)
        unsafe_store!(ptr, v)
    end
end

"""
    unsafe_getfield([unsafe_load,] ptr::Ptr{T}) -> v::T

Dereference a pointer `ptr` to an interior field of an immutable struct.  The
caller is responsible for rooting the object owning `ptr`.
"""
unsafe_getfield
@inline unsafe_getfield(ptr::Ptr) = unsafe_getfield(unsafe_load, ptr)
@inline function unsafe_getfield(unsafe_load, ptr::Ptr{T}) where {T}
    if ispointerfield(T)
        v = unsafe_pointer_to_objref(unsafe_load(Ptr{Ptr{Cvoid}}(ptr)))
    elseif T isa Union  # Union of immutables; load the type tag
        v = unsafe_load(Ptr{Some{T}}(ptr)).value
    else
        @assert !ismutabletype(T)
        v = unsafe_load(Ptr{T}(ptr))
    end
    return v::T
end

"""
    UnsafeFields.Demos

Example usages of UnsafeFields.

* `Mutable`: mutable wrapper of immutable object
* `StructView`: mutable reference to immutable object stored in array
"""
module Demos

export Mutable, StructView, freeze

using ..UnsafeFields: fieldindex, unsafe_getfield, unsafe_setfield!

abstract type UnsafeMutable{Immutable} end
datatype(::UnsafeMutable{Immutable}) where {Immutable} = Immutable
function root end

@inline Base.getproperty(x::UnsafeMutable, name::Symbol) =
    x[fieldindex(datatype(x), Val(name))]
@inline Base.setproperty!(x::UnsafeMutable, name::Symbol, v) =
    x[fieldindex(datatype(x), Val(name))] = v

@inline function Base.getindex(x::UnsafeMutable, i::Integer)
    FieldType = fieldtype(datatype(x), i)
    ptr = Ptr{FieldType}(pointer(x) + fieldoffset(datatype(x), i))
    r = root(x)
    GC.@preserve r begin
        v = unsafe_getfield(ptr)
    end
    return v
end

@inline function Base.setindex!(x::UnsafeMutable, v, i::Integer)
    FieldType = fieldtype(datatype(x), i)
    v = convert(FieldType, v)
    ptr = Ptr{FieldType}(pointer(x) + fieldoffset(datatype(x), i))
    r = root(x)
    GC.@preserve r begin
        unsafe_setfield!(ptr, v)
    end
end

"""
    Mutable(immutable)
    Mutable{I}([immutable::I])

Create a mutable wrapper of an immutable object (struct, tuple, or NamedTuple).
Use `freeze(::Mutable)` to extract out the immutable object.
"""
mutable struct Mutable{Data} <: UnsafeMutable{Data}
    data::Data
    Mutable{Data}(x::Data) where {Data} = new{Data}(x)
    Mutable{Data}() where {Data} = new{Data}()
end

Mutable(x::Data) where {Data} = Mutable{Data}(x)
Base.pointer(x::Mutable) = pointer_from_objref(x)
root(x::Mutable) = x

"""
    freeze(mutable::Mutable{I}) -> immutable::I

Extract out the `immutable` data stored in the `mutable` wrapper.
"""
freeze(x) = getfield(x, :data)

"""
    StructView(A::AbstractArray, I...)

A mutable reference to an immutable object stored at `A[I...]`.
"""
struct StructView{T,Root} <: UnsafeMutable{T}
    pointer::Ptr{T}
    root::Root
end

Base.pointer(x::StructView) = getfield(x, :pointer)
root(x::StructView) = getfield(x, :root)

function StructView(A::AbstractArray, I...)
    @boundscheck checkbounds(A, I...)
    return StructView(pointer(A, LinearIndices(A)[I...]), A)
end

end  # module Demos

end  # module UnsafeFields
