class packet_vc extends component_base;
	agent ag;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  ag = new("agent", this);
	endfunction

	function void configure(virtual port_if vif, int port_index);
	  ag.configure(vif, port_index);
	endfunction

	function mailbox #(packet) get_exp_mb();
	  return ag.drv_h.exp_mb;
	endfunction

	function mailbox #(packet) get_act_mb();
	  return ag.mon_h.act_mb;
	endfunction

	function monitor get_mon();
	  return ag.mon_h;
	endfunction

	task run(int num_packets);
	  fork
		ag.mon_h.run();         // monitor forever
		ag.drv_h.run(num_packets);
	  join_any
	endtask
endclass
