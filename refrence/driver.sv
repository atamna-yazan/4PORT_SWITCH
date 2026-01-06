class driver extends component_base;
	int count;
	virtual port_if vif;
	mailbox #(packet) mbox;

	function new(string n, component_base p=null);
	  super.new(n,p);
	endfunction

	function void configure(virtual port_if vif);
	  this.vif = vif;
	endfunction

	task run();
	  packet p;
	  count = 0;
	  forever begin
		mbox.get(p);
		@(posedge vif.clk);
		vif.valid_in  <= 1;
		vif.source_in <= p.source;
		vif.target_in <= p.target;
		vif.data_in   <= p.data;
		count ++;
		$display("[%0t] drived source=%b target=%b data=%b count =%d",$time, p.source, p.target, p.data,count);
		@(posedge vif.clk);
		vif.valid_in  <= 0;
	  end
	endtask

  endclass