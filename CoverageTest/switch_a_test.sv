module stage_a_test;

// -------------------------------------------------
// I. Clock & Reset
// -------------------------------------------------
logic clk;
logic rst_n;

initial begin
	clk = 0;
	forever #5 clk = ~clk;
end

// -------------------------------------------------
// II. Interfaces
// -------------------------------------------------
port_if IF_P0(clk, rst_n);
port_if IF_P1(clk, rst_n);
port_if IF_P2(clk, rst_n);
port_if IF_P3(clk, rst_n);

// -------------------------------------------------
// III. DUT
// -------------------------------------------------
switch_4port dut (
	.clk(clk),
	.rst_n(rst_n),
	.port0(IF_P0),
	.port1(IF_P1),
	.port2(IF_P2),
	.port3(IF_P3)
);

// -------------------------------------------------
// IV. Utility Tasks
// -------------------------------------------------

// Drive ALL inputs to known values (avoids X-propagation)
task automatic init_inputs();
	IF_P0.valid_in  = 0; IF_P0.source_in = 4'b0; IF_P0.target_in = 4'b0; IF_P0.data_in = 8'h00;
	IF_P1.valid_in  = 0; IF_P1.source_in = 4'b0; IF_P1.target_in = 4'b0; IF_P1.data_in = 8'h00;
	IF_P2.valid_in  = 0; IF_P2.source_in = 4'b0; IF_P2.target_in = 4'b0; IF_P2.data_in = 8'h00;
	IF_P3.valid_in  = 0; IF_P3.source_in = 4'b0; IF_P3.target_in = 4'b0; IF_P3.data_in = 8'h00;
endtask

// Apply reset (synchronous release)
task automatic apply_reset();
	rst_n = 0;
	repeat (3) @(posedge clk);
	rst_n = 1;
	@(posedge clk);
endtask

// Clear valids only (keep data stable)
task automatic clear_valids();
	IF_P0.valid_in = 0;
	IF_P1.valid_in = 0;
	IF_P2.valid_in = 0;
	IF_P3.valid_in = 0;
endtask

// Drive a packet on a given port for 1 cycle
task automatic drive_packet(
	input int src_port,
	input logic [3:0] target,
	input logic [7:0] data
);
	// default: no one drives valid except selected port
	clear_valids();

	case (src_port)
		0: begin
			IF_P0.source_in = 4'b0001;
			IF_P0.target_in = target;
			IF_P0.data_in   = data;
			IF_P0.valid_in  = 1'b1;
		end
		1: begin
			IF_P1.source_in = 4'b0010;
			IF_P1.target_in = target;
			IF_P1.data_in   = data;
			IF_P1.valid_in  = 1'b1;
		end
		2: begin
			IF_P2.source_in = 4'b0100;
			IF_P2.target_in = target;
			IF_P2.data_in   = data;
			IF_P2.valid_in  = 1'b1;
		end
		3: begin
			IF_P3.source_in = 4'b1000;
			IF_P3.target_in = target;
			IF_P3.data_in   = data;
			IF_P3.valid_in  = 1'b1;
		end
		default: begin
			$display("ERROR: src_port %0d invalid", src_port);
		end
	endcase

	@(posedge clk);
	clear_valids(); // single-cycle injection
endtask

// Wait up to N cycles for a specific output valid
task automatic wait_for_valid(
	input int dst_port,
	input int max_cycles,
	output bit seen
);
	seen = 0;
	for (int i = 0; i < max_cycles; i++) begin
		@(posedge clk);
		#1;
		case (dst_port)
			0: if (IF_P0.valid_out) seen = 1;
			1: if (IF_P1.valid_out) seen = 1;
			2: if (IF_P2.valid_out) seen = 1;
			3: if (IF_P3.valid_out) seen = 1;
		endcase
		if (seen) break;
	end
endtask

// -------------------------------------------------
// V. Tests
// -------------------------------------------------
initial begin
	rst_n = 1'b0;
	init_inputs();
	apply_reset();

	$display("\n--- Stage A QA Testbench START ---");

	// TEST 1: Single Destination (P0 -> P1)
	begin
		bit seen;
		$display("\n[TEST 1] Single Destination: P0 -> P1");
		drive_packet(0, 4'b0010, 8'hA1);
		wait_for_valid(1, 8, seen);

		if (seen && IF_P1.data_out == 8'hA1 &&
			!IF_P0.valid_out && !IF_P2.valid_out && !IF_P3.valid_out)
			$display("  [PASS] P0 -> P1 single-destination OK");
		else
			$display("  [FAIL] P0 -> P1 single-destination FAILED");
	end

	// TEST 2: Multicast (P0 -> P1 & P2)
	begin
		bit seen1, seen2;
		$display("\n[TEST 2] Multicast: P0 -> P1 & P2");

		drive_packet(0, 4'b0110, 8'hB2);

		// Wait for routing latency
		repeat (6) @(posedge clk);
		#1;

		seen1 = IF_P1.valid_out && IF_P1.data_out == 8'hB2;
		seen2 = IF_P2.valid_out && IF_P2.data_out == 8'hB2;

		if (seen1 && seen2)
			$display("  [PASS] Multicast routing OK");
		else
			$display("  [FAIL] Multicast routing FAILED");
	end

	// TEST 3: Broadcast (P0 -> All)
	begin
		bit s1, s2, s3;
		$display("\n[TEST 3] Broadcast: P0 -> All");

		drive_packet(0, 4'b1111, 8'hC3);

		repeat (6) @(posedge clk);
		#1;
		
		s1 = IF_P1.valid_out;
		s2 = IF_P2.valid_out;
		s3 = IF_P3.valid_out;

		if (s1 && s2 && s3)
			$display("  [PASS] Broadcast routing OK");
		else
			$display("  [FAIL] Broadcast routing FAILED");
	end

	// TEST 4: Different Source (P2 -> P3)
	begin
		bit seen;
		$display("\n[TEST 4] Single Destination: P2 -> P3");
		drive_packet(2, 4'b1000, 8'hD4);

		wait_for_valid(3, 8, seen);

		if (seen && IF_P3.data_out == 8'hD4)
			$display("  [PASS] Non-P0 source routing OK");
		else
			$display("  [FAIL] Non-P0 source routing FAILED");
	end

	// TEST 5: Reset Behavior
	begin
		$display("\n[TEST 5] Reset Behavior");
		rst_n = 0;
		@(posedge clk);
		#1;
		if (!IF_P0.valid_out && !IF_P1.valid_out && !IF_P2.valid_out && !IF_P3.valid_out)
			$display("  [PASS] Outputs low during reset");
		else
			$display("  [FAIL] Outputs not low during reset");

		rst_n = 1;
		@(posedge clk);
		#1;
		if (!IF_P0.valid_out && !IF_P1.valid_out && !IF_P2.valid_out && !IF_P3.valid_out)
			$display("  [PASS] Reset clears outputs");
		else
			$display("  [FAIL] Reset behavior FAILED");
	end

	$display("\n--- Stage A QA Testbench FINISHED ---");
	#20 $finish;
end

endmodule