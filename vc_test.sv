module vc_test;
  import packet_pkg::*;
  bit clk=0; always #5 clk=~clk; bit rst_n;
  port_if port0(clk,rst_n);
  initial begin
    rst_n=0; repeat(3) @(posedge clk); rst_n=1;
    packet_vc vc0=new("vc0",null);
    vc0.configure(port0,0);
    vc0.run(3);

    // Add checker
    // Implement functional coverage

    #200 $finish;
  end
endmodule
