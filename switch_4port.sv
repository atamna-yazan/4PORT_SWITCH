module switch_4port (
	input  logic clk,
	input  logic rst_n,
	port_if port0,
	port_if port1,
	port_if port2,
	port_if port3
);

	// Packet type for output FIFOs
	typedef struct packed {
	  logic [3:0] source;
	  logic [3:0] target;
	  logic [7:0] data;
	} pkt_t;

	localparam int OUT_FIFO_DEPTH = 8;
	localparam int PTR_W = $clog2(OUT_FIFO_DEPTH);

	// Output FIFOs
	pkt_t out_fifo [4][OUT_FIFO_DEPTH];
	logic [PTR_W:0] out_count [4];
	logic [PTR_W-1:0] rd_ptr [4], wr_ptr [4];

	// Port connections to switch_port blocks
	logic       v_out [4];
	logic [3:0] s_out [4], t_out [4];
	logic [7:0] d_out [4];

	// Instantiate ports
	genvar i;
	generate
	  for (i = 0; i < 4; i++) begin : PORTS
		switch_port P (
			.clk(clk), .rst_n(rst_n),
			.valid_in( (i==0) ? port0.valid_in : (i==1) ? port1.valid_in : (i==2) ? port2.valid_in : port3.valid_in ),
			.source_in( (i==0) ? port0.source_in : (i==1) ? port1.source_in : (i==2) ? port2.source_in : port3.source_in ),
			.target_in( (i==0) ? port0.target_in : (i==1) ? port1.target_in : (i==2) ? port2.target_in : port3.target_in ),
			.data_in(   (i==0) ? port0.data_in   : (i==1) ? port1.data_in   : (i==2) ? port2.data_in   : port3.data_in   ),
			.valid_out(v_out[i]),
			.source_out(s_out[i]),
			.target_out(t_out[i]),
			.data_out(d_out[i])
		);
	  end
	endgenerate

	// Combinational Enqueue Signals
	logic [3:0] do_enqueue;
	logic [3:0] do_dequeue;

	// Detect enqueue per output
	always_comb begin
	  do_enqueue = 4'b0000;
	  for (int i = 0; i < 4; i++) begin
		if (v_out[i]) begin
		  for (int o = 0; o < 4; o++) begin
			if (t_out[i][o] && out_count[o] < OUT_FIFO_DEPTH)
			  do_enqueue[o] = 1'b1;
		  end
		end
	  end
	end

	// Detect dequeue per output (when we drive a packet)
	always_comb begin
	  for (int o = 0; o < 4; o++) begin
		do_dequeue[o] = (out_count[o] > 0);
	  end
	end

	// Sequential block for FIFO state update
	always_ff @(posedge clk or negedge rst_n) begin
	  if (!rst_n) begin
		for (int o = 0; o < 4; o++) begin
		  rd_ptr[o]    <= '0;
		  wr_ptr[o]    <= '0;
		  out_count[o] <= '0;
		end
	  end else begin
		// Enqueue logic
		for (int i = 0; i < 4; i++) begin
		  if (v_out[i]) begin
			for (int o = 0; o < 4; o++) begin
			  if (t_out[i][o] && out_count[o] < OUT_FIFO_DEPTH) begin
				out_fifo[o][wr_ptr[o]] <= '{ source: s_out[i], target: t_out[i], data: d_out[i] };
				wr_ptr[o] <= wr_ptr[o] + 1;
			  end
			end
		  end
		end

		// Count and pointer updates
		for (int o = 0; o < 4; o++) begin
		  // Both enqueue and dequeue may happen in the same cycle
		  if (do_enqueue[o] && !do_dequeue[o])
			out_count[o] <= out_count[o] + 1;
		  else if (!do_enqueue[o] && do_dequeue[o])
			out_count[o] <= out_count[o] - 1;

		  if (do_dequeue[o])
			rd_ptr[o] <= rd_ptr[o] + 1;
		end
	  end
	end

	// Output logic
	always_comb begin
	  for (int o = 0; o < 4; o++) begin
		automatic logic v = (out_count[o] > 0);
		automatic logic [3:0] src = out_fifo[o][rd_ptr[o]].source;
		automatic logic [3:0] tgt = out_fifo[o][rd_ptr[o]].target;
		automatic logic [7:0] dat = out_fifo[o][rd_ptr[o]].data;
		
		case (o)
		  0: begin
			port0.valid_out  = v;
			port0.source_out = src;
			port0.target_out = tgt;
			port0.data_out   = dat;
		  end
		  1: begin
			port1.valid_out  = v;
			port1.source_out = src;
			port1.target_out = tgt;
			port1.data_out   = dat;
		  end
		  2: begin
			port2.valid_out  = v;
			port2.source_out = src;
			port2.target_out = tgt;
			port2.data_out   = dat;
		  end
		  3: begin
			port3.valid_out  = v;
			port3.source_out = src;
			port3.target_out = tgt;
			port3.data_out   = dat;
		  end
		endcase
	  end
	end

endmodule
