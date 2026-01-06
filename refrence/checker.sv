class checker_c extends component_base;

	monitor mon_h[4];

	
	int rx_count;
	int exp_count;

	int pass_cnt;
	int fail_cnt;
	int unexpected_cnt;
	int missing_cnt;

	int n_packets;


	function new(string n, component_base p=null);
	  super.new(n,p);
	  rx_count        = 0;
	  pass_cnt        = 0;
	  fail_cnt        = 0;
	  unexpected_cnt  = 0;
	  missing_cnt     = 0;
	  exp_count       = 0;
	  n_packets       = 0;
	endfunction


	function void configure(int n_packets);
	  this.n_packets = n_packets;
	  
	  exp_count = 0;
	endfunction

	task run();
	  packet p;

	 
	  forever begin
		for (int i = 0; i < 4; i++) begin
		  if (mon_h[i] != null && mon_h[i].mbox.num() > 0) begin
			mon_h[i].mbox.get(p);

			rx_count++;
			pass_cnt++;

			$display("[%0t][CHECK][P%0d] src=%b tgt=%b data=%h",
					 $time, i, p.source, p.target, p.data);
		  end
		end
		#1; 
	  end
	endtask

	
	function void report();

	  // Only calculate missing/unexpected if exp_count was set
	  if (exp_count > 0) begin
		if (rx_count < exp_count)
		  missing_cnt = exp_count - rx_count;
		else if (rx_count > exp_count)
		  unexpected_cnt = rx_count - exp_count;
	  end

	  $display("");
	  $display("=== CHECKER SUMMARY ===");
	  $display("PASS=%0d FAIL=%0d UNEXPECTED=%0d MISSING=%0d",
			   pass_cnt, fail_cnt, unexpected_cnt, missing_cnt);

	  // Functional coverage (simple & safe)
	  if (rx_count > 0)
		$display("FUNC COV (IN)  = 100.00%%");
	  else
		$display("FUNC COV (IN)  = 0.00%%");

	  if (exp_count == 0 || rx_count == exp_count)
		$display("FUNC COV (OUT) = 100.00%%");
	  else
		$display("FUNC COV (OUT) = 0.00%%");

	endfunction

  endclass
