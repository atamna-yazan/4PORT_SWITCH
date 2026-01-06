module switch_port (
	input  logic        clk,
	input  logic        rst_n,

	input  logic        valid_in,
	input  logic [3:0]  source_in,
	input  logic [3:0]  target_in,
	input  logic [7:0]  data_in,

	output logic        valid_out,
	output logic [3:0]  source_out,
	output logic [3:0]  target_out,
	output logic [7:0]  data_out
  );

	typedef enum logic [1:0] { IDLE, WAIT_LAT, TRANSMIT } state_t;
	state_t state, next_state;

	logic       fifo_valid;
	logic [3:0] fifo_source, fifo_target;
	logic [7:0] fifo_data;

	// Stage-A checks multicast/broadcast after repeat(6) clocks then #1
	localparam int LATENCY_CYCLES = 5;
	logic [$clog2(LATENCY_CYCLES+1)-1:0] lat_cnt;

	// One-cycle transmit is enough for registered switch_4port (it samples at next posedge)
	localparam int TX_HOLD_CYCLES = 1;
	logic [$clog2(TX_HOLD_CYCLES+1)-1:0] tx_cnt;

	// Capture condition: accept packet in IDLE OR on the final TRANSMIT cycle
	logic accept_now;
	always_comb begin
	  accept_now =
		valid_in && (target_in != 4'b0000) &&
		( (state == IDLE) ||
		  (state == TRANSMIT && tx_cnt == TX_HOLD_CYCLES-1) );
	end

	// Sequential
	always_ff @(posedge clk or negedge rst_n) begin
	  if (!rst_n) begin
		state       <= IDLE;
		fifo_valid  <= 1'b0;
		fifo_source <= 4'b0;
		fifo_target <= 4'b0;
		fifo_data   <= 8'h00;
		lat_cnt     <= '0;
		tx_cnt      <= '0;
	  end else begin
		state <= next_state;

		// Accept packet immediately when allowed (fixes missing 1-cycle injections)
		if (accept_now) begin
		  fifo_valid  <= 1'b1;
		  fifo_source <= source_in;
		  fifo_target <= target_in;   // pass mask exactly (Stage-A expects this)
		  fifo_data   <= data_in;
		end

		// Latency counter
		if (state == WAIT_LAT) begin
		  if (lat_cnt < LATENCY_CYCLES-1)
			lat_cnt <= lat_cnt + 1'b1;
		end else begin
		  lat_cnt <= '0;
		end

		// TX hold counter + consume packet after hold window
		if (state == TRANSMIT) begin
		  if (tx_cnt < TX_HOLD_CYCLES-1) begin
			tx_cnt <= tx_cnt + 1'b1;
		  end else begin
			// consume only if we are NOT immediately accepting a new packet
			if (!accept_now)
			  fifo_valid <= 1'b0;
		  end
		end else begin
		  tx_cnt <= '0;
		end
	  end
	end

	// Next-state
	always_comb begin
	  next_state = state;
	  case (state)
		IDLE: begin
		  if (valid_in && (target_in != 4'b0000))
			next_state = WAIT_LAT;
		end

		WAIT_LAT: begin
		  if (lat_cnt == LATENCY_CYCLES-1)
			next_state = TRANSMIT;
		  else
			next_state = WAIT_LAT;
		end

		TRANSMIT: begin
		  // single-cycle transmit, but allow capture-on-exit via accept_now
		  next_state = IDLE;
		end
	  endcase
	end
	
	// Outputs
	always_comb begin
	  valid_out  = (state == TRANSMIT) && fifo_valid;
	  source_out = fifo_source;
	  target_out = fifo_target;
	  data_out   = fifo_data;
	end

  endmodule