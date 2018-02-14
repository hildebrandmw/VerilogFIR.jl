using DSP
using VerilogFIR

# Create a low pass filter using DPS
coeffs = digitalfilter(Lowpass(5; fs=50), FIRWindow(hamming(8)));
# Create the Filter
generate_fir("filter.v",coeffs,w_input=16,w_output=16)
