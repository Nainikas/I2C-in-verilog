//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nainika Saha
// Design Name: iic_controller_tb
// Module Name: iic_controller_tb
// Description: Tests I2C
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module iic_controller_tb;
    reg clk;
    reg rst;
    reg sda_slave; // Slave device driving SDA
    wire sda_master;
    wire scl;
    wire sda;

    reg [6:0] test_slave_addr;
    reg [7:0] test_data;

    // Corrected Pull-Up Logic for SDA
    assign sda = (sda_master === 1'bz && sda_slave === 1'bz) ? 1'b1 : 
                 (sda_master !== 1'bz) ? sda_master : 
                 sda_slave;

    // Instantiate the IIC controller
    iic_controller uut (
        .clk(clk),
        .rst(rst),
        .slave_addr(test_slave_addr),
        .data(test_data),
        .sda(sda_master),
        .scl(scl)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Slave behavior for acknowledgment
    initial begin
        sda_slave = 1'bz; // Default to released
        wait(uut.state == uut.ACK_WAIT); // Wait for ACK phase
        @(negedge scl); // Wait for SCL low
        sda_slave = 1'b0; // Pull SDA low (ACK)
        @(posedge scl); // Release SDA after SCL high
        sda_slave = 1'bz;
    end

    // Test sequence
    initial begin
        test_slave_addr = 7'h42; // Example test slave address
        test_data = 8'b10101010; // Example test data

        rst = 1;
        #20;
        rst = 0;

        $monitor("Time=%0t, SCL=%b, SDA=%b, State=%0d", $time, scl, sda, uut.state);

        wait (uut.state == uut.DONE);

        $display("Test completed.");
        $stop;
    end
endmodule
