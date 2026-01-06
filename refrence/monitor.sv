class monitor extends component_base;

	virtual port_if vif;
	mailbox #(packet) mbox;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  mbox = new();
	endfunction

	function void configure(virtual port_if vif);
	  this.vif = vif;
	endfunction

	task run();
	  packet p;
	  forever begin
		@(posedge vif.clk iff vif.valid_out);
		p = new();
		p.source = vif.source_out;
		p.target = vif.target_out;
		p.data   = vif.data_out;
		mbox.put(p);
	  end
	endtask

  endclass