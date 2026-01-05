module switch_test;
import packet_pkg::*;

// -------------------
// Clock + Reset
// -------------------
bit clk = 0;
always #5 clk = ~clk;

bit rst_n;

// -------------------
// Interfaces
// -------------------
port_if port0(clk, rst_n);
port_if port1(clk, rst_n);
port_if port2(clk, rst_n);
port_if port3(clk, rst_n);

// -------------------
// DUT
// -------------------
switch_4port dut(
  .clk  (clk),
  .rst_n(rst_n),
  .port0(port0),
  .port1(port1),
  .port2(port2),
  .port3(port3)
);

// -------------------
// Class handles
// -------------------
packet_vc      vc0, vc1, vc2, vc3;
\checker chk;   // <-- your checker class from checker.sv

// -------------------
// Test
// -------------------
initial begin
  $display("### SWITCH_TEST STARTED at time %0t ###", $time);
  driver::drive_sem = new(1);
  // Reset sequence
  rst_n = 0;
  repeat (3) @(posedge clk);
  rst_n = 1;
  @(posedge clk);

  // Construct VCs
  vc0 = new("vc0", null);
  vc1 = new("vc1", null);
  vc2 = new("vc2", null);
  vc3 = new("vc3", null);

  // Configure VCs (bind virtual interfaces + source port index)
  vc0.configure(port0, 0);
  vc1.configure(port1, 1);
  vc2.configure(port2, 2);
  vc3.configure(port3, 3);

  // Construct checker
  chk = new("chk", null);

  // Connect expected mailboxes (from drivers)
  chk.connect_exp(0, vc0.get_exp_mb());
  chk.connect_exp(1, vc1.get_exp_mb());
  chk.connect_exp(2, vc2.get_exp_mb());
  chk.connect_exp(3, vc3.get_exp_mb());

  // Connect actual mailboxes (from monitors)
  chk.connect_act(0, vc0.get_act_mb());
  chk.connect_act(1, vc1.get_act_mb());
  chk.connect_act(2, vc2.get_act_mb());
  chk.connect_act(3, vc3.get_act_mb());

  // Start checker threads
  chk.run();

  // Run the 4 VCs concurrently (contention happens naturally)
  	fork
	  vc0.run(300);
	  vc1.run(300);
	  vc2.run(300);
	  vc3.run(300);
	join
 
  repeat (20) @(posedge clk);

  // Final summary + assertions
  chk.report_and_assert();

  $display("### SWITCH_TEST FINISHED at time %0t ###", $time);
  $finish;
end

endmodule