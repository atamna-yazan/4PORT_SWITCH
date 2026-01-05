class switch_coverage;

	packet pkt;

	// Helper function
	function automatic int ones4(bit [3:0] v);
	  return $countones(v);
	endfunction

	covergroup cg_switch @(pkt);
	  option.per_instance = 1;

	  // Packet type
	  cp_type : coverpoint pkt.type_enum {
		  bins single = {packet::SINGLE};
		  bins m2     = {packet::MULTICAST_2};
		  bins m3     = {packet::MULTICAST_3};
		  bins bc     = {packet::BROADCAST};
		}

	  // Source port
	  cp_src : coverpoint pkt.source{
		bins p0 = {0};
		bins p1 = {1};
		bins p2 = {2};
		bins p3 = {3};
	  }

	  // Number of destinations
	  cp_fanout : coverpoint ones4(pkt.target) {
		bins one   = {1};
		bins two   = {2};
		bins three = {3};
		bins four  = {4};
	  }

	  // Target patterns (optional but powerful)
	  cp_target : coverpoint pkt.target {
		bins uni[] = {4'b0001,4'b0010,4'b0100,4'b1000};
		bins mc[]  = {[4'b0011:4'b1110]};
		bins bc    = {4'b1111};
	  }

	  // Cross coverage
	  cross_type_src   : cross cp_type, cp_src;
	  cross_type_fanout: cross cp_type, cp_fanout;

	endgroup

	function new();
	  cg_switch = new();
	endfunction

	function void sample(packet p);
	  pkt = p;
	  cg_switch.sample();
	endfunction

  endclass
