//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nainika Saha
// Design Name: iic_controller
// Module Name: iic_controller
// Description: Controls I2C
//////////////////////////////////////////////////////////////////////////////////

module iic_controller (
    input wire clk,       // 100 kHz clock
    input wire rst,
    input wire [6:0] slave_addr, // Slave address passed as input
    input wire [7:0] data,       // Data passed as input
    inout wire sda,
    output reg scl
);

    // State Encoding
    localparam IDLE = 4'd0;
    localparam START = 4'd1;
    localparam SEND_SLAVE_ADDR = 4'd2;
    localparam ACK_WAIT = 4'd3;
    localparam SEND_RW_BIT = 4'd4;
    localparam SEND_DATA = 4'd5;
    localparam READ_DATA = 4'd6;
    localparam DATA_ACK_WAIT = 4'd7;
    localparam STOP = 4'd8;
    localparam DONE = 4'd9;

    reg [3:0] state, next_state;
    reg [7:0] data_reg;
    reg [6:0] slave_addr_reg;
    reg [2:0] bit_counter;
    reg rw_bit;
    reg sda_drive;
    reg sda_data;
    reg ack_received;
    reg [9:0] scl_counter;

    // SCL Clock Divider
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_counter <= 10'd0;
            scl <= 1;
        end else if (scl_counter == 10'd9) begin
            scl_counter <= 10'd0;
            scl <= ~scl; // Toggle SCL
        end else begin
            scl_counter <= scl_counter + 1;
        end
    end

    // SDA Line Control
    assign sda = (sda_drive) ? sda_data : 1'bz;

    // State Machine
    always @(posedge scl or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            slave_addr_reg <= slave_addr; // Initialize from input
            data_reg <= data;             // Initialize from input
            bit_counter <= 6;
            ack_received <= 0;
            sda_data <= 0;
            sda_drive <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        if (rst) begin
            next_state = IDLE;
            sda_drive = 0;
            sda_data = 1; // Release SDA to high
            bit_counter = 6; // Reset bit counter
            ack_received = 0;
        end else begin
            next_state = state;
            sda_drive = 0; // Default: release SDA
            sda_data = 0;  // Default: SDA high (idle state)

            case (state)
                IDLE: begin
                    sda_drive = 0;
                    sda_data = 0;
                    rw_bit = 0; // Set to 0 for write, 1 for read (default: write)
                    next_state = START;
                end

                START: begin
                    sda_drive = 1;
                    sda_data = 0; // Start condition: SDA goes low
                    next_state = SEND_SLAVE_ADDR;
                end

                SEND_SLAVE_ADDR: begin
                    sda_drive = 1;
                    sda_data = slave_addr_reg[bit_counter]; // Output slave address bit
                    if (bit_counter == 0 && scl == 0) begin
                        next_state = ACK_WAIT; // Transition to ACK_WAIT when SCL is low
                    end else if (scl == 0) begin
                        bit_counter = bit_counter - 1; // Decrement bit counter
                    end
                end

                ACK_WAIT: begin
                    sda_drive = 0; // Release SDA
                    if (scl == 1) begin
                        ack_received = (sda === 1'b0); // Sample SDA during SCL high (ACK is low)
                        $display("ACK_WAIT: Time=%0dns, SCL=%b, SDA=%b, ACK_Received=%b", $time, scl, sda, ack_received);
                    end
                    if (scl == 0 && ack_received == 0) begin
                        next_state = SEND_RW_BIT; // Proceed if ACK is received
                    end else if (scl == 0) begin
                        next_state = STOP; // Stop if no ACK
                    end
                end

                SEND_RW_BIT: begin
                    sda_drive = 1;
                    sda_data = rw_bit; // Send R/W bit
                    if (rw_bit) begin
                        next_state = READ_DATA; // If R/W bit is 1, transition to READ_DATA
                    end else begin
                        next_state = SEND_DATA; // If R/W bit is 0, transition to SEND_DATA
                    end
                    bit_counter = 7; // Reset bit counter
                end

                SEND_DATA: begin
                    sda_drive = 1;
                    sda_data = data_reg[bit_counter]; // Send data bit by bit
                    if (bit_counter == 0 && scl == 0) begin
                        next_state = DATA_ACK_WAIT; // Transition to DATA_ACK_WAIT after last bit
                    end else if (scl == 0) begin
                        bit_counter = bit_counter - 1; // Decrement bit counter during SCL low
                    end
                end

                READ_DATA: begin
                    sda_drive = 0; // Release SDA to allow the slave to drive it
                    if (scl == 1) begin
                        // Read data bit by bit during SCL high
                        data_reg[bit_counter] = sda;
                        if (bit_counter == 0) begin
                            next_state = DATA_ACK_WAIT; // Transition to ACK wait state after reading all bits
                        end else if (scl == 0) begin
                            bit_counter = bit_counter - 1; // Decrement bit counter during SCL low
                        end
                    end
                end

                DATA_ACK_WAIT: begin
                    sda_drive = 0; // Release SDA to allow slave to drive it
                    if (scl == 1) begin
                        ack_received = (sda === 1'b0); // Sample SDA for ACK during SCL high
                        $display("DATA_ACK_WAIT: Time=%0dns, SCL=%b, SDA=%b, ACK_Received=%b", $time, scl, sda, ack_received);
                    end
                    if (scl == 0 && ack_received) begin
                        next_state = STOP; // Proceed to STOP if ACK is received
                    end else if (scl == 0) begin
                        next_state = STOP; // Stop transaction if no ACK
                    end
                end

                STOP: begin
                    sda_drive = 1;
                    sda_data = 1; // Stop condition: SDA high
                    if (scl == 1) begin
                        next_state = DONE; // End transaction
                    end
                end

                DONE: begin
                    next_state = IDLE; // Go back to idle state
                end
            endcase
        end
    end
endmodule
