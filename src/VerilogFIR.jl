module VerilogFIR

export generate_fir

# max and min values for n bit number in 2s complement
maxrep(n) = 2^(n-1)-1
minrep(n) = -2^(n-1)

fminabs(x...) = floor(Int64, minimum(abs.(x)))
clog2(x) = ceil(Int64, log2(x))
flog2(x) = floor(Int64, log2(x))

nbits_u(x) = clog2(x+1)
nbits_s(x) = x > 0 ? clog2(x+1)+1 : clog2(-x)+1

tab(n) = " "^(4n)


################################################################################
# Top level function
################################################################################
function generate_fir(file::String, coeffs; kwargs...)
    io = open(file, "w")
    generate_fir(io, coeffs; kwargs...)
    close(io)
end

function generate_fir(io::IO, coeffs; w_input = 8, w_output = 8, w_coeff = 8)
    # Scale coefficients
    scaled_coeffs, bitshift = scale_coefficients(coeffs, w_coeff)

    # Compute the number of taps
    taps  = length(scaled_coeffs)
    w_acc = acc_width(scaled_coeffs, w_input)

    # Generate Verilog header
    header(io, w_input, w_output)
    declarations(io, w_input, w_coeff, w_acc, taps)
    initialize(io, scaled_coeffs, w_coeff)
    register_input(io, taps)
    gen_filter(io, taps)
    output(io, w_output, bitshift)
    endmodule(io)
end

@doc """
    generate_fir(io::Union{IO,String}, coeffs; w_input, w_output, w_coeff)

Generate Verilog for a multicycle FIR filter described by `coeffs`. If `io` is
an `IO`, output will be written directly to `io`. Otherwise, if `io` is a
`String`, a file will be created with the name of `io` and output will be
written to that file.

# Key word arguments
* `w_input` - Bitwidth of the input. Default: `8`.
* `w_output` - Bitwidth of the output. Default: `8`.
* `w_coeff` - Bitwidth of the coefficients. Default: `8`.
""" generate_fir

################################################################################
# Analysis Functions
################################################################################

function scale_coefficients(coeffs, w_coeff)
    minval, maxval = extrema(coeffs)
    # Determine scale factor
    pos_scale = maxrep(w_coeff)/maxval
    neg_scale = minrep(w_coeff)/minval
    # Get the maximum number we can multiply coefficients by to get while still
    # remaining within the bit width designated for the coefficients.
    maxfactor = fminabs(pos_scale, neg_scale)
    # Convert to the largest power of 2 less than maxfactor
    factor = 2^flog2(maxfactor)
    return round.(Int64, factor * coeffs), flog2(factor)
end

function acc_width(scaled_coeffs, w_input)
    minval = minrep(w_input)
    maxval = maxrep(w_input)
    # Compute the maximum and minimum values for the output of this filter
    maxoutput = 0
    minoutput = 0
    for c in scaled_coeffs
        if c > 0
            maxoutput += maxval*c
            minoutput += minval*c
        elseif c < 0
            maxoutput += minval*c
            minoutput += maxval*c
        end
    end
    bits_for_max = nbits_s(maxoutput)
    bits_for_min = nbits_s(minoutput)
    return max(bits_for_max, bits_for_min)
end


################################################################################
# Printing functions
################################################################################
function header(io, w_input, w_output)
    print(io,"""
        module filter(
                // Interface signals
                input clk,
                input start,
                output reg done,
                // Data Signals
                input  [$(w_input-1):0] data_in,
                output reg [$(w_output-1):0] data_out
            );
        """)
end

function declarations(io, w_input, w_coeff, w_acc, taps)
    print(io,"""
            // Coefficient Storage
            reg signed [$(w_coeff-1):0] coeff [$(taps-1):0];
            reg signed [$(w_input-1):0] data  [$(taps-1):0];
            // Counter for iterating through coefficients.
            reg [$(clog2(taps)-1):0] count;
            // Accumulator
            reg signed [$(w_acc-1):0] acc;

            // State machine signals
            localparam IDLE = 0;
            localparam RUN  = 1;

            reg state;
        """)
end

function initialize(io, coeff, w_coeff)
    # Print initial statement
    print(io, "\n")
    print(io, tab(1), "initial begin\n")
    for (i,c) in enumerate(coeff)
        print(io, tab(2), "coeff[$(i-1)] = $c;\n")
    end
    # end initial block
    print(io, tab(1), "end\n")
end

function register_input(io, taps)
    print(io, """
            always @(posedge clk) begin : capture
                integer i;
                if (start) begin
                    for (i = 0; i < $(taps-1) ; i = i+1) begin
                        data[i+1] <= data[i];
                    end
                    data[0] <= data_in;
                end
            end
        """)
end

function gen_filter(io, taps)
    print(io, """
            always @(posedge clk) begin
                case (state)
                    IDLE: begin
                        done <= 1'b0;
                        if (start) begin
                            count <= $(taps-1);
                            acc   <= 0;
                            state <= RUN;
                        end
                    end

                    RUN: begin
                        count <= count - 1'b1;
                        acc   <= acc + data[count] * coeff[count];
                        if (count == 0) begin
                            state <= IDLE;
                            done  <= 1'b1;
                        end
                    end
                endcase
            end
        """)
end

function output(io, w_output, bitshift)
    print(io, """
            always @(posedge clk) begin
                if (done) begin
                    data_out <= acc[$(bitshift + w_output - 1):$(bitshift)];
                end
            end
        """)
end


function endmodule(io)
    print(io, "endmodule")
end
end # module
