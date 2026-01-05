class agent extends component_base;
	sequencer seq_h;
	driver    drv_h;
	monitor   mon_h;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  seq_h = new("seq", this);
	  drv_h = new("drv", this);
	  mon_h = new("mon", this);
	endfunction

	function void configure(virtual port_if vif, int port_index);
	  seq_h.port_index = port_index;
	  drv_h.configure(vif, seq_h);
	  mon_h.configure(vif);
	endfunction
  endclass