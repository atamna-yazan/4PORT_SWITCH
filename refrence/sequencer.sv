class sequencer extends component_base;

	mailbox #(packet) mbox;

	function new(string n, component_base p=null);
	  super.new(n,p);
	  mbox = new();
	endfunction

	task run(int n_packets);
	  packet p;
	  int src_idx;
	  int tgt_idx;
	  bit [3:0] mask;

	  repeat (n_packets) begin
		p = new();

		// -------- SOURCE (one-hot) --------
		src_idx  = $urandom_range(0,3);
		p.source = 4'b0001 << src_idx;

		// -------- TARGET TYPE --------
		case ($urandom_range(0,2))

		  // ---------- UNICAST ----------
		  0: begin
			do tgt_idx = $urandom_range(0,3);
			while (tgt_idx == src_idx);
			p.target = 4'b0001 << tgt_idx;
		  end

		  // ---------- MULTICAST ----------
		  1: begin
			mask = 0;
			while ($countones(mask) < 2) begin
			  tgt_idx = $urandom_range(0,3);
			  if (tgt_idx != src_idx)
				mask[tgt_idx] = 1'b1;
			end
			p.target = mask;
		  end

		  // ---------- BROADCAST ----------
		  2: begin
			p.target = 4'b1111 & ~p.source;
		  end

		endcase

		// -------- DATA --------
		p.data = $urandom;

		mbox.put(p);
	  end
	endtask

  endclass
