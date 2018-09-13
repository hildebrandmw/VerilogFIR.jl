using VerilogFIR
using Test

@testset "Testing Auxiliary Functions" begin
    # maxrep
    for (i,j) in zip((2,3,4,5,6),(1,3,7,15,31))
        @test VerilogFIR.maxrep(i) == j
    end
    # minrep
    for (i,j) in zip((2,3,4,5,6),(2,4,8,16,32))
        @test VerilogFIR.minrep(i) == -j
    end
    # fminabs
    let
        t1 = (1.0, 10, -400, -0.1)
        @test VerilogFIR.fminabs(t1...) == 0
        # Test case when a division by 0 occurs, make sure result is still correct.
        t2 = (Inf, 1.1)
        @test VerilogFIR.fminabs(t2...) == 1
        t3 = (-Inf, Inf, -2.3)
        @test VerilogFIR.fminabs(t3...) == 2
    end
    # clog2
    let
        tests       = (1,2,3,2.5,100.23)
        expected    = (0,1,2,2,7)
        for (t,e) in zip(tests, expected)
            @test VerilogFIR.clog2(t) == e
        end
    end
    # flog2
    let
        tests       = (1,2,3,2.5,100.23)
        expected    = (0,1,1,1,6)
        for (t,e) in zip(tests, expected)
            @test VerilogFIR.flog2(t) == e
        end
    end
    # nbits_u
    let
        tests    = (6,7,8,9)
        expected = (3,3,4,4)
        for (t,e) in zip(tests, expected)
            @test VerilogFIR.nbits_u(t) == e
        end
    end
    # nbits_s
    let
        tests    = (7,8,9,-7,-8,-9)
        expected = (4,5,5,4,4,5)
        for (t,e) in zip(tests, expected)
            @test VerilogFIR.nbits_s(t) == e
        end
    end
    # tab
    let
        @test VerilogFIR.tab(1) == "    "
        @test VerilogFIR.tab(2) == "        "
    end
    # makedict
    let
        a = 1
        b = [10,20,30]
        c = "hello"
        d = 5
        f = 2.21
        dict = VerilogFIR.@makedict a b c d f
        expected = Dict(
            :a => 1,
            :b => [10,20,30],
            :c => "hello",
            :d => 5,
            :f => 2.21,
        )
        @test dict == expected
    end
end

#=
Tests for functions that scale coefficients.
=#
@testset "Testing Analysis Functions" begin
    # Test coefficient scaling
    let
        # Test with all positive numbers

        ## TEST 1
        coeffs = [2,1,1]
        w_coeff = 3
        @test VerilogFIR.scale_coefficients(coeffs, w_coeff) == ([2,1,1],0)

        ## TEST 2
        w_coeff = 4
        @test VerilogFIR.scale_coefficients(coeffs, w_coeff) == ([4,2,2],1)

        ## TEST 3
        # Test with negative numbers
        # With the same values as TEST 1, should scale since negative numbers
        # have one extra number to work with on the low end.
        coeffs = [-2,-1,-1]
        w_coeff = 3
        @test VerilogFIR.scale_coefficients(coeffs, w_coeff) == ([-4,-2,-2],1)

        ## TEST 4
        # Test with positive and negative numbers
        coeffs = [2,0,-2]
        w_coeff = 3
        @test VerilogFIR.scale_coefficients(coeffs, w_coeff) == ([2,0,-2],0)

        ## TEST 5
        w_coeff = 4
        @test VerilogFIR.scale_coefficients(coeffs, w_coeff) == ([4,0,-4],1)

        ## TEST 6
        coeffs = [1,0,-2]
        w_coeff = 3
        @test VerilogFIR.scale_coefficients(coeffs, w_coeff) == ([2,0,-4],1)
    end
    # Test accumulator width
    let
        coeffs = [1,-2,0,-1,3]
        w_input = 4
        # Get the maximum positive and negative values that can be represented
        # with 4 bits
        big     = 7
        little  = -8
        # Compute maximum and minimum values for the filter
        maxval = 7*(1+3) + -8*(-1-2)
        minval = -8*(1+3) + 7*(-1-2)
        # Get the number of bits for each
        bits_max = VerilogFIR.nbits_s(maxval)
        bits_min = VerilogFIR.nbits_s(minval)
        nbits = min(bits_max, bits_min)
        @test VerilogFIR.acc_width(coeffs, w_input) == nbits
    end
end

@testset "Testing complete run" begin
    generate_fir(stdout, ones(4)/4, w_input = 16, w_output = 16, w_coeff = 12)
    generate_fir(stdout, ones(4)/4, w_input = 8,  w_output = 8, w_coeff = 21)
    generate_fir(stdout, ones(4)/4, w_input = 16, w_output = 8, w_coeff = 9)
    # Test generating saturating logic
    generate_fir(ones(8))

    @test_throws InexactError generate_fir(stdout, ones(4)/4, w_coeff = 1)
    # Test with file
    file = "test15713209.v"
    generate_fir(file, ones(4)/4)
    rm(file)
end
