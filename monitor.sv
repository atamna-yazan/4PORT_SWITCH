class monitor extends component_base;
	virtual port_if vif;

	mailbox #(packet) act_mb;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  act_mb = new();
	endfunction

	function void configure(virtual port_if vif);
	  this.vif = vif;
	endfunction

	task run();
	  packet p;

	  // Wait for reset release
	  while (vif.rst_n === 0) @(posedge vif.clk);

	  forever begin
		vif.collect_packet(p);
		// p already contains source/target/data from interface task
		p.post_randomize(); // to set type_enum based on target (safe)
		$display("[%s] MON:   Src=%b Tgt=%b Data=%02h Type=%s",
				 pathname(), p.source, p.target, p.data, p.type_enum.name());
		act_mb.put(p);
	  end
	endtask
  endclass