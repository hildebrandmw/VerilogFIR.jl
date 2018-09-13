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

macro makedict(args...)
    return esc(:(Dict($([:($(QuoteNode(i)) => $i) for i in args]...))))
end

################################################################################
# Top level function
################################################################################
generate_fir(args...; kwargs...) = generate_fir(STDOUT, args...; kwargs...)

function generate_fir(file::String, args...; kwargs...)
    io = open(file, "w")
    generate_fir(io, args...; kwargs...)
    close(io)
end

function generate_fir(
        io::IO, coeffs; 
        w_input   = 8, 
        w_output  = 8, 
        w_coeff   = 8,
    )

    # Scale coefficients
    scaled_coeffs, bitshift = scale_coefficients(coeffs, w_coeff)

    # Compute the number of taps
    taps  = length(scaled_coeffs)
    w_acc = acc_width(scaled_coeffs, w_input)

    d = @makedict w_input w_output w_coeff scaled_coeffs bitshift taps w_acc

    # Generate Verilog header
    header(io, d)
    declarations(io, d)
    initialize(io, d)
    register_input(io, d)
    gen_filter(io, d)
    output(io, d)
    endmodule(io, d)
end

@doc """
    generate_fir(io::Union{IO,String}, coeffs; w_input, w_output, w_coeff)

Generate Verilog for a multicycle FIR filter described by `coeffs`. If `io` is
an `IO`, output will be written directly to `io`. Otherwise, if `io` is a
`String`, a file will be created with the name of `io` and output will be
written to that file.

# Key word arguments
* `w_input`  - Bitwidth of the input. Default: `8`.
* `w_output` - Bitwidth of the output. Default: `8`.
* `w_coeff`  - Bitwidth of the coefficients. Default: `8`.
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
function header(io, d)
    print(io,"""
        module filter(
                // Interface signals
                input clk,
                input start,
                output reg done,
                // Data Signals
                input  [$(d[:w_input]-1):0] data_in,
                output reg [$(d[:w_output]-1):0] data_out
            );
        """)
end

function declarations(io, d)
    print(io,"""
            // Coefficient Storage
            reg signed [$(d[:w_coeff]-1):0] coeff [$(d[:taps]-1):0];
            reg signed [$(d[:w_input]-1):0] data  [$(d[:taps]-1):0];
            // Counter for iterating through coefficients.
            reg [$(clog2(d[:taps])-1):0] count;
            // Accumulator
            reg signed [$(d[:w_acc]-1):0] acc;

            // State machine signals
            localparam IDLE = 0;
            localparam RUN  = 1;

            reg state;
        """)
end

function initialize(io, d)
    # Print initial statement
    print(io, "\n")
    print(io, tab(1), "initial begin\n")
    for (i,c) in enumerate(d[:scaled_coeffs])
        print(io, tab(2), "coeff[$(i-1)] = $c;\n")
    end
    # end initial block
    print(io, tab(1), "end\n")
end

function register_input(io, d)
    print(io, """
            always @(posedge clk) begin : capture
                integer i;
                if (start) begin
                for (i = 0; i < $(d[:taps]-1) ; i = i+1) begin
                        data[i+1] <= data[i];
                    end
                    data[0] <= data_in;
                end
            end
        """)
end

function gen_filter(io, d)
    print(io, """
            always @(posedge clk) begin
                case (state)
                    IDLE: begin
                        done <= 1'b0;
                        if (start) begin
                            count <= $(d[:taps]-1);
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

function output(io, d)
    output_left = d[:bitshift] + d[:w_output] - 1
    # Determine if saturation detection is needed for the output
    saturate = output_left < d[:w_acc] - 1

    if saturate
        print(io, """
                always @(posedge clk) begin
                    if (done) begin
                        // Saturate if necessary
                        if (acc >= 2 ** $(output_left)) begin
                            data_out <= $(maxrep(d[:w_output]));
                        end else if (acc < -(2 ** $(output_left))) begin
                            data_out <= $(minrep(d[:w_output]));
                        end else begin
                            data_out <= acc[$output_left:$(d[:bitshift])];
                        end
                    end
                end
            """)
    else
        print(io, """
                always @(posedge clk) begin
                    if (done) begin
                        data_out <= acc[$output_left:$(d[:bitshift])];
                    end
                end
            """)
    end
end


function endmodule(io, d)
    print(io, "endmodule")
end
end # module
