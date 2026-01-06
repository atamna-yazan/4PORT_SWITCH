class switch_coverage;
	packet pkt;

	// Helper function
	function automatic int ones4(bit [3:0] v);
	  return $countones(v);
	endfunction
	
	covergroup cg_switch;

	  // Packet type
	  cp_type : coverpoint pkt.type_enum {
		bins single = {packet::SINGLE};
		bins m2     = {packet::MULTICAST_2};
		bins m3     = {packet::MULTICAST_3};
		bins bc     = {packet::BROADCAST};
	  }

	  // Source port
	  cp_src : coverpoint pkt.source {
		  bins p0 = {4'b0001};
		  bins p1 = {4'b0010};
		  bins p2 = {4'b0100};
		  bins p3 = {4'b1000};
		  illegal_bins not_onehot = default;
		}

	  // Number of destinations
	  cp_fanout : coverpoint ones4(pkt.target) {
		bins one   = {1};
		bins two   = {2};
		bins three = {3};
		bins four  = {4};
	  }

	  // Target patterns
	  cp_target : coverpoint pkt.target {
		bins uni[] = {4'b0001,4'b0010,4'b0100,4'b1000};
		bins mc2[]  = {4'b0011,4'b0101,4'b1001,4'b1010,4'b1100,4'b0110};
		bins mc3[] = {4'b0111,4'b1110,4'b1011,4'b1101};
		bins bc    = {4'b1111};
	  }

	  // Cross coverage
	  cross_type_src    : cross cp_type, cp_src;
	endgroup
	
	function new();
	  cg_switch = new(); 
	endfunction

	function void sample(packet p);
	  pkt = p;
	  cg_switch.sample();
	endfunction
endclass