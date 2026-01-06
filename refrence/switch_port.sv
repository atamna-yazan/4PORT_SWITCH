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

	localparam int NUM_PORTS = 4;
	typedef enum logic [1:0] {
	  S_IDLE     = 2'b00,
	  S_RECEIVE  = 2'b01,
	  S_ROUTE    = 2'b10,
	  S_TRANSMIT = 2'b11
	} state_t;

	state_t state, state_n;
	logic [3:0] src_r,     src_n;
	logic [7:0] dat_r,     dat_n;

	logic [3:0] pending_r, pending_n;
	logic [1:0] rr_ptr_r,  rr_ptr_n;    


	logic [3:0] source_out_n, target_out_n;
	logic [7:0] data_out_n;
	logic       valid_out_n;

	function automatic logic [3:0] rr_pick_onehot(
	  input  logic [3:0] mask,
	  input  logic [1:0] start,
	  output logic [1:0] next_start
	);
	  logic [3:0] sel;
	  int i;
	  logic [1:0] idx;

	  sel        = 4'b0000;
	  next_start = start;

	  for (i = 0; i < NUM_PORTS; i++) begin
		idx = start + logic'(i[1:0]);  
		if (mask[idx] && (sel == 4'b0000)) begin
		  sel        = 4'b0000;
		  sel[idx]   = 1'b1;              
		  next_start = idx + 2'd1;
		end
	  end

	  return sel;
	endfunction


	logic [3:0] sel_dest;
	logic [1:0] rr_ptr_after_pick;

	always_comb begin
	 
	  state_n    = state;

	  src_n      = src_r;
	  dat_n      = dat_r;
	  pending_n  = pending_r;
	  rr_ptr_n   = rr_ptr_r;

	  
	  source_out_n = source_out;
	  target_out_n = target_out;
	  data_out_n   = data_out;
	  valid_out_n  = 1'b0;

	  sel_dest = 4'b0000;

	  case (state)
		
		S_IDLE: begin
		  if (valid_in) begin
			src_n     = source_in;
			dat_n     = data_in;

			pending_n = (target_in & ~source_in);
			state_n   = S_RECEIVE;
		  end
		end

		S_RECEIVE: begin
	
		  if (pending_r == 4'b0000) begin
			state_n = S_IDLE;
		  end else begin
			state_n = S_ROUTE;
		  end
		end

	
		S_ROUTE: begin
		  sel_dest = rr_pick_onehot(pending_r, rr_ptr_r, rr_ptr_after_pick);

		  if (sel_dest == 4'b0000) begin
			state_n = S_IDLE;
		  end else begin
			
			source_out_n = src_r;
			target_out_n = sel_dest;   
			data_out_n   = dat_r;

			rr_ptr_n     = rr_ptr_after_pick;
			state_n      = S_TRANSMIT;
		  end
		end

	
		S_TRANSMIT: begin
		  
		  valid_out_n = 1'b1;

		  
		  pending_n = pending_r & ~target_out;

		  if (pending_n == 4'b0000) begin
			state_n = S_IDLE;
		  end else begin
			state_n = S_ROUTE;
		  end
		end

		default: state_n = S_IDLE;
	  endcase
	end
	always_ff @(posedge clk or negedge rst_n) begin
	  if (!rst_n) begin
		state      <= S_IDLE;

		src_r      <= 4'b0000;
		dat_r      <= 8'h00;
		pending_r  <= 4'b0000;
		rr_ptr_r   <= 2'd0;

		valid_out  <= 1'b0;
		source_out <= 4'b0000;
		target_out <= 4'b0000;
		data_out   <= 8'h00;

	  end else begin
		state      <= state_n;

		src_r      <= src_n;
		dat_r      <= dat_n;
		pending_r  <= pending_n;
		rr_ptr_r   <= rr_ptr_n;

		valid_out  <= valid_out_n;
		source_out <= source_out_n;
		target_out <= target_out_n;
		data_out   <= data_out_n;
	  end
	end

  endmodule