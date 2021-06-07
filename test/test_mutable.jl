module TestMutable

using UnsafeFields.Demos: Mutable, freeze
using Test

struct Values2{A,B}
    a::A
    b::B
end

#=
struct Values3{A,B,C}
    a::A
    b::B
    c::C
end
=#

@testset "Tuple{Int, Int}" begin
    mut = Mutable((111, 222))
    @test (mut[1], mut[2]) == freeze(mut) == (111, 222)
    mut[1] = 3
    mut[2] = 4
    @test (mut[1], mut[2]) == freeze(mut) == (3, 4)
end

@testset "Values2{String,Symbol}" begin
    mut = Mutable(Values2("initial string", :initial_symbol))
    @test (mut.a, mut.b) == ("initial string", :initial_symbol)
    mut.a = "second string"
    mut.b = :second_symbol
    @test (mut.a, mut.b) == ("second string", :second_symbol)
end

@testset "Values2{Union{String,Int,Nothing},Union{Int,Nothing,Float64}}" begin
    mut = Mutable(
        Values2{Union{String,Int,Nothing},Union{Int,Nothing,Float64}}(nothing, nothing),
    )
    @test (mut.a, mut.b) === (nothing, nothing)
    mut.a = "second string"
    mut.b = 222
    @test (mut.a, mut.b) === ("second string", 222)
    mut.a = 111
    mut.b = 333.0
    @test (mut.a, mut.b) === (111, 333.0)
end

@testset "Values2{Any,Union{Integer,Symbol}}" begin
    mut = Mutable(Values2{Any,Union{Integer,Symbol}}(0, 0))
    @test (mut.a, mut.b) === (0, 0)
    mut.a = "second string"
    mut.b = :second_symbol
    @test (mut.a, mut.b) == ("second string", :second_symbol)
end

end  # module
