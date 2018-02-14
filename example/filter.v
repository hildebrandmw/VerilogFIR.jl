module filter(
        // Interface signals
        input clk,
        input start,
        output reg done,
        // Data Signals
        input  [15:0] data_in,
        output reg [15:0] data_out
    );
    // Coefficient Storage
    reg signed [7:0] coeff [7:0];
    reg signed [15:0] data  [7:0];
    // Counter for iterating through coefficients.
    reg [2:0] count;
    // Accumulator
    reg signed [23:0] acc;

    // State machine signals
    localparam IDLE = 0;
    localparam RUN  = 1;

    reg state;

    initial begin
        coeff[0] = 2;
        coeff[1] = 12;
        coeff[2] = 42;
        coeff[3] = 71;
        coeff[4] = 71;
        coeff[5] = 42;
        coeff[6] = 12;
        coeff[7] = 2;
    end
    always @(posedge clk) begin : capture
        integer i;
        if (start) begin
            for (i = 0; i < 7 ; i = i+1) begin
                data[i+1] <= data[i];
            end
            data[0] <= data_in;
        end
    end
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    count <= 7;
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
    always @(posedge clk) begin
        if (done) begin
            data_out <= acc[23:8];
        end
    end
endmodule