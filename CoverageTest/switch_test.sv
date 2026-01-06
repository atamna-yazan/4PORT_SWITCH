module switch_test;

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
switch_coverage sw_cov;
switch_port_fsm_coverage fsm_cov0, fsm_cov1, fsm_cov2, fsm_cov3;

task automatic sample_packet(
		input logic [3:0] src,
		input logic [3:0] tgt,
		input logic [7:0] dat
	  );
		packet pkt = new("sample_pkt");
		pkt.source = src;
		pkt.target = tgt;
		pkt.data   = dat;
		pkt.post_randomize();
		sw_cov.sample(pkt);
	  endtask
// -------------------
// Test
// -------------------
initial begin
  $display("### SWITCH_TEST STARTED at time %0t ###", $time);
  driver::drive_sem = new(1);
  sw_cov = new();
  // fsm instanting
  fsm_cov0 = new();
  fsm_cov1 = new();
  fsm_cov2 = new();
  fsm_cov3 = new();
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
// -----------------------------
// COVERAGE SAMPLING (FSM)
// -----------------------------
always @(posedge clk) begin
	if (rst_n) begin
	  fsm_cov0.sample(
		switch_port_fsm_coverage::state_t'(dut.P0.state)
	  );
	  fsm_cov1.sample(
		switch_port_fsm_coverage::state_t'(dut.P1.state)
	  );
	  fsm_cov2.sample(
		switch_port_fsm_coverage::state_t'(dut.P2.state)
	  );
	  fsm_cov3.sample(
		switch_port_fsm_coverage::state_t'(dut.P3.state)
	  );
	end
  end

// -----------------------------
// COVERAGE SAMPLING (INPUT PACKETS)
// -----------------------------
always @(posedge clk) begin
	if (port0.valid_in)
	  sample_packet(port0.source_in, port0.target_in, port0.data_in);

	if (port1.valid_in)
	  sample_packet(port1.source_in, port1.target_in, port1.data_in);

	if (port2.valid_in)
	  sample_packet(port2.source_in, port2.target_in, port2.data_in);

	if (port3.valid_in)
	  sample_packet(port3.source_in, port3.target_in, port3.data_in);
end

// -----------------------------
// COVERAGE SAMPLING (OUTPUT PACKETS)
// -----------------------------
always @(posedge clk) begin
	if (port0.valid_out)
	  sample_packet(port0.source_out, port0.target_out, port0.data_out);

	if (port1.valid_out)
	  sample_packet(port1.source_out, port1.target_out, port1.data_out);

	if (port2.valid_out)
	  sample_packet(port2.source_out, port2.target_out, port2.data_out);

	if (port3.valid_out)
	  sample_packet(port3.source_out, port3.target_out, port3.data_out);
end

endmodule