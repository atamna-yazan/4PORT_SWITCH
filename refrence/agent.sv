class agent extends component_base;

	sequencer seq;
	driver    drv;
	monitor   mon;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  seq = new({n,"_seq"}, this);
	  drv = new({n,"_drv"}, this);
	  mon = new({n,"_mon"}, this);
	endfunction

	function void configure(virtual port_if vif);
	  drv.configure(vif);
	  mon.configure(vif);
	  // @SuppressProblem -type elab_error -count 1 -length 1
	  drv.mbox = seq.mbox;
	endfunction

	task run(int n_packets);
	  fork
		// @SuppressProblem -type elab_error -count 1 -length 1
		seq.run(n_packets);
		drv.run();
		mon.run();
	  join_none
	endtask

  endclass