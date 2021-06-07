module TestStructView

using UnsafeFields.Demos: StructView
using Test

struct Values2{A,B}
    a::A
    b::B
end

@testset "Tuple{Int, Int}" begin
    A = [(111, 222), (333, 444), (555, 666)]
    mut = StructView(A, 1)
    @test (mut[1], mut[2]) === A[1] === (111, 222)
    mut[1] = 3
    mut[2] = 4
    @test (mut[1], mut[2]) === A[1] === (3, 4)
end

@testset "Values2{String,Symbol}" begin
    A = [Values2("initial string", :initial_symbol)]
    load() = (A[1].a, A[1].b)
    mut = StructView(A, 1)
    @test (mut.a, mut.b) === load() === ("initial string", :initial_symbol)
    mut.a = "second string"
    mut.b = :second_symbol
    @test (mut.a, mut.b) === load() === ("second string", :second_symbol)
end

@testset "Values2{Union{String,Int,Nothing},Union{Int,Nothing,Float64}}" begin
    A = [
        Values2{Union{String,Int,Nothing},Union{Int,Nothing,Float64}}(nothing, nothing)
    ]
    load() = (A[1].a, A[1].b)
    mut = StructView(A, 1)
    @test (mut.a, mut.b) === load() === (nothing, nothing)
    mut.a = "second string"
    mut.b = 222
    @test (mut.a, mut.b) === load() === ("second string", 222)
    mut.a = 111
    mut.b = 333.0
    @test (mut.a, mut.b) === load() === (111, 333.0)
end

@testset "Values2{Any,Union{Integer,Symbol}}" begin
    A = [Values2{Any,Union{Integer,Symbol}}(0, 0)]
    load() = (A[1].a, A[1].b)
    mut = StructView(A, 1)
    @test (mut.a, mut.b) === load() === (0, 0)
    mut.a = "second string"
    mut.b = :second_symbol
    @test (mut.a, mut.b) === load() == ("second string", :second_symbol)
end

end  # module
