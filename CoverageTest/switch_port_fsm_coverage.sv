class switch_port_fsm_coverage;
	typedef enum logic [1:0] { IDLE, WAIT_LAT, TRANSMIT } state_t;
	state_t state;

	covergroup cg_fsm;
	  option.per_instance = 1;
	  cp_state : coverpoint state {
		bins idle     = {IDLE};
		bins wait_lat = {WAIT_LAT};
		bins transmit = {TRANSMIT};
	  }
	endgroup

	function new();
	  cg_fsm = new();
	endfunction

	function void sample(state_t s);
	  state = s;
	  cg_fsm.sample();
	endfunction
	
  endclass
