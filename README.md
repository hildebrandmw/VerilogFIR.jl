# VerilogFIR

[![Build Status](https://travis-ci.org/hildebrandmw/VerilogFIR.jl.svg?branch=master)](https://travis-ci.org/hildebrandmw/VerilogFIR.jl)
[![Coverage](https://codecov.io/gh/hildebrandmw/VerilogFIR.jl/branch/master/graphs/badge.svg?branch=master)](https://codecov.io/gh/hildebrandmw/VerilogFIR.jl/branch/master)

Small package for generating multi-cycle Verilog FIR filters automatically with
from a set of coefficients and selected bit widths. This package was written
to fulfill a small need I had during the course of my work. Contributions are
very welcome!

This package exports a single function:

```julia
generate_fir(io::Union{IO,String}, coeffs; w_input, w_output, w_coeff)
```

Generate Verilog for a multicycle FIR filter described by `coeffs`. If `io` is
an `IO`, output will be written directly to `io`. Otherwise, if `io` is a
`String`, a file will be created with the name of `io` and output will be
written to that file.

Key word arguments:
* `w_input` - Bitwidth of the input. Default: `8`.
* `w_output` - Bitwidth of the output. Default: `8`.
* `w_coeff` - Bitwidth of the coefficients. Default: `8`.

# Installation
This package is not registered. Obtain it in Julia using the following command:
```julia
Pkg.add("https://github.com/hildebrandmw/VerilogFIR.jl")
```

# Filter HDL
The generated Verilog filter has the following port list:
```verilog
module filter(
        // Interface signals
        input clk,
        input start,
        output reg done,
        // Data Signals
        input  [w_input-1:0] data_in,
        output reg [w_output:0] data_out
    );
```
Upon assertion of `start`, `filter` will sample `data_in` and perform a 
multicycle filter of the last `N = length(coeffs)` data points. In general, this
will take `N` cycles. Upon completion of the filter, `done` will be asserted
for a single clock cycle. At this point, `data_out` is valid.

Input coefficients are scaled by some power of 2 to take advantage of the given 
coefficient bitwidth. An analysis is performed on the resulting filter 
coefficients to size the accumulator correctly so it will never overflow. The
final output is shifted by the scaling amount.

An example usage is shown in `examples/example.jl`. The generated Verilog is
given in `examples/filter.v`.
