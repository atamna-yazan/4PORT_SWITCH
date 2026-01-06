module switch_4port (
	input  logic clk,
	input  logic rst_n,
	port_if port0,
	port_if port1,
	port_if port2,
	port_if port3
  );

	localparam int NUM_PORTS   = 4;
	localparam int FIFO_DEPTH  = 4;
	localparam int PTR_W       = (FIFO_DEPTH <= 2) ? 1 : $clog2(FIFO_DEPTH);

	typedef struct packed {
	  logic [3:0] src;
	  logic [3:0] tgt;
	  logic [7:0] dat;
	  logic       ok;   
	} pkt_t;

	typedef enum logic [1:0] {
	  ST_IDLE     = 2'b00,
	  ST_RECEIVE  = 2'b01,
	  ST_ROUTE    = 2'b10,
	  ST_TRANSMIT = 2'b11
	} fsm_state_t;

	fsm_state_t state   [NUM_PORTS];
	fsm_state_t state_n [NUM_PORTS];

	logic       vin   [NUM_PORTS];
	logic [3:0] srcin [NUM_PORTS];
	logic [3:0] tgtin [NUM_PORTS];
	logic [7:0] datin [NUM_PORTS];

	logic       vout   [NUM_PORTS];
	logic [3:0] srcout [NUM_PORTS];
	logic [3:0] tgtout [NUM_PORTS];
	logic [7:0] datout [NUM_PORTS];

	always_comb begin
	  vin[0]=port0.valid_in; srcin[0]=port0.source_in; tgtin[0]=port0.target_in; datin[0]=port0.data_in;
	  vin[1]=port1.valid_in; srcin[1]=port1.source_in; tgtin[1]=port1.target_in; datin[1]=port1.data_in;
	  vin[2]=port2.valid_in; srcin[2]=port2.source_in; tgtin[2]=port2.target_in; datin[2]=port2.data_in;
	  vin[3]=port3.valid_in; srcin[3]=port3.source_in; tgtin[3]=port3.target_in; datin[3]=port3.data_in;
	end

	always_comb begin
	  port0.valid_out=vout[0]; port0.source_out=srcout[0]; port0.target_out=tgtout[0]; port0.data_out=datout[0];
	  port1.valid_out=vout[1]; port1.source_out=srcout[1]; port1.target_out=tgtout[1]; port1.data_out=datout[1];
	  port2.valid_out=vout[2]; port2.source_out=srcout[2]; port2.target_out=tgtout[2]; port2.data_out=datout[2];
	  port3.valid_out=vout[3]; port3.source_out=srcout[3]; port3.target_out=tgtout[3]; port3.data_out=datout[3];
	end

	function automatic logic is_onehot4(input logic [3:0] x);
	  return (x==4'b0001)||(x==4'b0010)||(x==4'b0100)||(x==4'b1000);
	endfunction

	function automatic logic [3:0] legal_pending(
	  input logic [3:0] src,
	  input logic [3:0] tgt
	);
	  return (tgt & ~src);
	endfunction

	function automatic logic accept_pkt(
	  input logic v,
	  input logic [3:0] s,
	  input logic [3:0] t
	);
	  return v && is_onehot4(s) && (legal_pending(s,t) != 4'b0000);
	endfunction


	pkt_t      fifo_mem [NUM_PORTS][FIFO_DEPTH];
	logic[3:0] pend_mem [NUM_PORTS][FIFO_DEPTH];

	logic [PTR_W-1:0] wr_ptr [NUM_PORTS];
	logic [PTR_W-1:0] rd_ptr [NUM_PORTS];
	logic [PTR_W:0]   count  [NUM_PORTS];

	pkt_t      head_pkt  [NUM_PORTS];
	logic[3:0] head_pend [NUM_PORTS];

	function automatic logic [NUM_PORTS-1:0] rr_pick(
	  input  logic [NUM_PORTS-1:0] req,
	  input  logic [1:0]           start,
	  output logic [1:0]           next
	);
	  logic [NUM_PORTS-1:0] g='0;
	  next=start;
	  for (int k=0;k<NUM_PORTS;k++) begin
		int idx=(start+k)%NUM_PORTS;
		if (req[idx] && g=='0) begin
		  g[idx]=1;
		  next=idx+1;
		end
	  end
	  return g;
	endfunction

	logic [1:0] rr_ptr_r[NUM_PORTS], rr_ptr_n[NUM_PORTS];
	logic [NUM_PORTS-1:0] req[NUM_PORTS], gnt[NUM_PORTS];
	logic [3:0] served[NUM_PORTS];


	always_comb begin
	
	  for (int o=0;o<NUM_PORTS;o++) begin
		vout[o]=0; srcout[o]=0; tgtout[o]=0; datout[o]=0;


		for (int i=0;i<NUM_PORTS;i++) begin
		  req[o][i] = (count[i]!=0) && head_pkt[i].ok && head_pend[i][o];
		end

		gnt[o]=rr_pick(req[o],rr_ptr_r[o],rr_ptr_n[o]);
	  end

	  for (int i=0;i<NUM_PORTS;i++) served[i]='0;

	
	  for (int o=0;o<NUM_PORTS;o++) begin
		for (int i=0;i<NUM_PORTS;i++) begin
		  if (gnt[o][i]) begin
			vout[o]=1;
			srcout[o]=head_pkt[i].src;
			tgtout[o]=head_pkt[i].tgt;
			datout[o]=head_pkt[i].dat;
			served[i][o]=1;
		  end
		end
	  end

	  for (int i=0;i<NUM_PORTS;i++) begin
		if ((count[i]!=0) && !head_pkt[i].ok) begin
		  automatic int o = i;
	
		  srcout[o]=head_pkt[i].src;
		  tgtout[o]=head_pkt[i].tgt;
		  datout[o]=head_pkt[i].dat;
		end
	  end
	end

	
	generate
	  for (genvar gi=0;gi<NUM_PORTS;gi++) begin
		logic we, pop;
		logic ok_in;
		logic [3:0] in_pend, pend_after;
		logic pop_invalid;

		always_comb begin
		  
		  we     = vin[gi] && (count[gi] < FIFO_DEPTH);

		  ok_in  = accept_pkt(vin[gi],srcin[gi],tgtin[gi]);
		  in_pend = legal_pending(srcin[gi],tgtin[gi]); // used only if ok_in=1 (otherwise ignored)
		  pend_after = head_pend[gi] & ~served[gi];

		  
		  pop_invalid = (count[gi]!=0) && !head_pkt[gi].ok;

		  
		  pop = pop_invalid ||
				((count[gi]!=0) && (served[gi] != '0) && (pend_after == '0));

		  state_n[gi]=state[gi];
		  case (state[gi])
			ST_IDLE:       if (we)        state_n[gi]=ST_RECEIVE;
			ST_RECEIVE:                  state_n[gi]=ST_ROUTE;
			ST_ROUTE:      if (pop)       state_n[gi]=ST_TRANSMIT;
			ST_TRANSMIT:   state_n[gi] = (count[gi]>1) ? ST_ROUTE : ST_IDLE;
		  endcase
		end

		always_ff @(posedge clk or negedge rst_n) begin
		  if (!rst_n) begin
			state[gi]   <= ST_IDLE;
			wr_ptr[gi]  <= '0;
			rd_ptr[gi]  <= '0;
			count[gi]   <= '0;
			head_pkt[gi]  <= '{default:0};
			head_pend[gi] <= '0;
		  end else begin
			state[gi] <= state_n[gi];

			if (we) begin
			  fifo_mem[gi][wr_ptr[gi]] <= '{src:srcin[gi], tgt:tgtin[gi], dat:datin[gi], ok:ok_in};
			  pend_mem[gi][wr_ptr[gi]] <= (ok_in ? in_pend : 4'b0000);

			  wr_ptr[gi] <= wr_ptr[gi] + 1'b1;
			  count[gi]  <= count[gi] + 1'b1;

			  if (count[gi]==0) begin
				head_pkt[gi]  <= '{src:srcin[gi], tgt:tgtin[gi], dat:datin[gi], ok:ok_in};
				head_pend[gi] <= (ok_in ? in_pend : 4'b0000);
			  end
			end

			
			if (count[gi]!=0 && head_pkt[gi].ok)
			  head_pend[gi] <= pend_after;

			if (pop) begin
			  rd_ptr[gi] <= rd_ptr[gi] + 1'b1;
			  count[gi]  <= count[gi] - 1'b1;

			  if (count[gi] > 1) begin
				head_pkt[gi]  <= fifo_mem[gi][rd_ptr[gi]+1];
				head_pend[gi] <= pend_mem[gi][rd_ptr[gi]+1];
			  end else begin
				head_pkt[gi]  <= '{default:0};
				head_pend[gi] <= '0;
			  end
			end
		  end
		end
	  end
	endgenerate

	always_ff @(posedge clk or negedge rst_n)
	  if (!rst_n)
		for (int o=0;o<NUM_PORTS;o++) rr_ptr_r[o] <= '0;
	  else
		for (int o=0;o<NUM_PORTS;o++) rr_ptr_r[o] <= rr_ptr_n[o];

  endmodule