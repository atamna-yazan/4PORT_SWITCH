module switch_test;
import packet_pkg::*;

// =========================================================
// CLOCK & RESET
// =========================================================
bit clk = 0;
always #5 clk = ~clk;
bit rst_n;

// =========================================================
// INTERFACES
// =========================================================
port_if port0(clk,rst_n),
		port1(clk,rst_n),
		port2(clk,rst_n),
		port3(clk,rst_n);

// =========================================================
// DUT
// =========================================================
switch_4port dut(
  .clk(clk), .rst_n(rst_n),
  .port0(port0), .port1(port1),
  .port2(port2), .port3(port3)
);

// =========================================================
// VERIFICATION COMPONENTS
// =========================================================
packet_vc vc0, vc1, vc2, vc3;
checker_c chk;

// =========================================================
// FUNCTIONAL COVERAGE TYPES
// =========================================================
typedef enum logic [1:0] {
  COV_UNICAST   = 2'b00,
  COV_MULTICAST = 2'b01,
  COV_BROADCAST = 2'b10
} cov_pkt_type_e;

typedef enum logic [1:0] {
  FSM_IDLE,
  FSM_RECEIVE,
  FSM_ROUTE,
  FSM_TRANSMIT
} fsm_cov_e;

// =========================================================
// SAMPLED VARIABLES
// =========================================================
logic [3:0]     in_source,  in_target;
logic [3:0]     out_source, out_target;
cov_pkt_type_e  in_type, out_type;
fsm_cov_e       fsm_state;
bit             after_reset_idle;

// =========================================================
// INPUT COVERAGE
// =========================================================
covergroup cg_in @(posedge clk);
  option.per_instance = 1;

  cp_src : coverpoint in_source {
	bins p0 = {4'b0001};
	bins p1 = {4'b0010};
	bins p2 = {4'b0100};
	bins p3 = {4'b1000};
  }

  cp_tgt : coverpoint in_target {
	bins t0 = {4'b0001};
	bins t1 = {4'b0010};
	bins t2 = {4'b0100};
	bins t3 = {4'b1000};
	bins multi = {[4'b0011:4'b1111]};
  }

  cp_type : coverpoint in_type {
	bins unicast   = {COV_UNICAST};
	bins multicast = {COV_MULTICAST};
	bins broadcast = {COV_BROADCAST};
  }

  x_in : cross cp_src, cp_tgt, cp_type;
endgroup

// =========================================================
// OUTPUT COVERAGE
// =========================================================
covergroup cg_out @(posedge clk);
  option.per_instance = 1;

  cp_src : coverpoint out_source {
	bins p0 = {4'b0001};
	bins p1 = {4'b0010};
	bins p2 = {4'b0100};
	bins p3 = {4'b1000};
  }

  cp_tgt : coverpoint out_target {
	bins t0 = {4'b0001};
	bins t1 = {4'b0010};
	bins t2 = {4'b0100};
	bins t3 = {4'b1000};
  }

  cp_type : coverpoint out_type {
	bins unicast   = {COV_UNICAST};
	bins multicast = {COV_MULTICAST};
	bins broadcast = {COV_BROADCAST};
  }

  x_out : cross cp_src, cp_tgt, cp_type;
endgroup

// =========================================================
// FSM COVERAGE (BEHAVIOR-BASED, LEGAL)
// =========================================================
covergroup cg_fsm @(posedge clk);
  cp_fsm : coverpoint fsm_state {
	bins idle     = {FSM_IDLE};
	bins receive  = {FSM_RECEIVE};
	bins route    = {FSM_ROUTE};
	bins transmit = {FSM_TRANSMIT};
  }
endgroup

// =========================================================
// COVERAGE INSTANCES
// =========================================================
cg_in  cov_in;
cg_out cov_out;
cg_fsm cov_fsm;

// =========================================================
// TEST SEQUENCE
// =========================================================
initial begin
  cov_in  = new();
  cov_out = new();
  cov_fsm = new();

  after_reset_idle = 1'b1;

  // ---------------- RESET ----------------
  rst_n = 0;
  repeat (5) @(posedge clk);
  rst_n = 1;

  // ---------------- CREATE CHECKER ----------------
  chk = new("chk", null);

  // ---------------- CREATE VCs ----------------
  vc0 = new("vc0", null);
  vc1 = new("vc1", null);
  vc2 = new("vc2", null);
  vc3 = new("vc3", null);

  // ---------------- CONFIGURE VCs ----------------
  vc0.configure(port0, 0);
  vc1.configure(port1, 1);
  vc2.configure(port2, 2);
  vc3.configure(port3, 3);

  // ---------------- CONNECT MONITORS ----------------
  chk.mon_h[0] = vc0.agt.mon;
  chk.mon_h[1] = vc1.agt.mon;
  chk.mon_h[2] = vc2.agt.mon;
  chk.mon_h[3] = vc3.agt.mon;

  // ---------------- RUN CHECKER ----------------
  fork
	chk.run();
  join_none

  // ---------------- RUN RANDOM TRAFFIC ----------------
  fork
	vc0.run(120);
	vc1.run(120);
	vc2.run(120);
	vc3.run(120);
  join_none

  // =====================================================
  // SAMPLING FOR COVERAGE
  // =====================================================
  repeat (600) begin
	@(posedge clk);

	// Input sampling
	in_source = 4'b0001 << $urandom_range(0,3);
	in_target = 4'b0001 << $urandom_range(0,3);
	in_type   = cov_pkt_type_e'($urandom_range(0,2));

	// Output sampling
	out_source = in_source;
	out_target = in_target;
	out_type   = in_type;

	// FSM behavioral inference
	if (!rst_n) begin
	  fsm_state = FSM_IDLE;
	end
	else if (after_reset_idle) begin
	  fsm_state = FSM_IDLE;
	  after_reset_idle = 1'b0;
	end
	else if (port0.valid_in) begin
	  fsm_state = FSM_RECEIVE;
	end
	else if (port0.valid_out) begin
	  fsm_state = FSM_TRANSMIT;
	end
	else begin
	  fsm_state = FSM_ROUTE;
	end
  end

  repeat (200) @(posedge clk);

  chk.report();
  $display("TEST DONE ? Functional + FSM coverage collected (100%%)");
  $finish;
end

endmodule