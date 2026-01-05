class packet; 
	rand bit [7:0] data;
	rand bit [3:0] target;
	bit [3:0] source;
	string name;

	// Packet type enum - NOT RAND, its value is calculated in post_randomize()
	typedef enum {SINGLE, MULTICAST_2, MULTICAST_3, BROADCAST, UNCONSTRAINED} type_t;
	type_t type_enum = UNCONSTRAINED;

	// Project requirement: Static counter to track creations
	static int packet_count = 0;

	// --- Helper function: Counts set bits (used for constraints) ---
	function automatic int count_ones(bit [3:0] vec);
	return $countones(vec);
	endfunction

	// --- CONSOLIDATED CONSTRUCTOR ---
	function new(string name, int port_index = -1);
	this.name = name;
	this.packet_count = packet_count+1;
	if (port_index != -1) begin
	// CRITICAL FIX: Ensure this line is clean and single-line
	this.source = 1'b1 << port_index;
	end
	endfunction

	// --- Base Constraints: Apply to all valid packets ---
	constraint valid_base_rules {
	// 1. Target cannot be zero (must go somewhere)
	target != 4'b0000;
	// 2. Target must have at least one set bit (specific counts enforced in derived classes)
	count_ones(target) inside {[1:4]};
	}
	// check if source is valid
	constraint source_valid {
		source inside {4'b0001,4'b0010,4'b0100,4'b1000};
	  }
	// Serves the monitor stage
	function void update_type();
		int ones = count_ones(target);
		if (ones == 1)      type_enum = SINGLE;
		else if (ones == 2) type_enum = MULTICAST_2;
		else if (ones == 3) type_enum = MULTICAST_3;
		else if (ones == 4) type_enum = BROADCAST;
		else                type_enum = UNCONSTRAINED;
	endfunction
	
	// clone the packet for driver
	function packet clone();
		packet c = new(this.name);
		c.source = this.source;
		c.target = this.target;
		c.data   = this.data;
		c.type_enum = this.type_enum;
		return c;
	  endfunction

	// --- Post-Randomization: Assign type_enum after fields are set ---
	function void post_randomize();
	int ones = count_ones(target);
	if (ones == 1) begin
	type_enum = SINGLE;
	end else if (ones == 2) begin
	type_enum = MULTICAST_2;
	end else if (ones == 3) begin
	type_enum = MULTICAST_3;
	end else if (ones == 4) begin
	type_enum = BROADCAST;
	end
	endfunction
	endclass