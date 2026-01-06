class driver extends component_base;
	virtual port_if vif;
	sequencer        seq_h;

	mailbox #(packet) exp_mb;

	// Global semaphore for serialization
	static semaphore drive_sem;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  exp_mb = new();
	endfunction

	function void configure(virtual port_if vif, sequencer seq_h);
	  this.vif   = vif;
	  this.seq_h = seq_h;
	endfunction

	task run(int num_packets);
	  packet p;

	  while (vif.rst_n === 0) @(posedge vif.clk);

	  for (int i = 0; i < num_packets; i++) begin
		int gap = $urandom_range(8, 10);
		repeat (gap) @(posedge vif.clk);

		// 🔒 Acquire lock
		drive_sem.get(1);

		seq_h.get_next_packet(p);

		$display("[%s] DRIVE: Src=%b Tgt=%b Data=%02h Type=%s Time=%0t",
				 pathname(), p.source, p.target, p.data,
				 p.type_enum.name(), $time);

		exp_mb.put(p);
		vif.drive_packet(p);

		repeat (20) @(posedge vif.clk);

		// 🔓 Release lock
		drive_sem.put(1);
	  end
	endtask
  endclass
