class sequencer extends component_base;
	int port_index;
	rand packet::type_t type_to_generate;

	constraint packet_type_dist {
	  type_to_generate dist {
		packet::SINGLE       := 2,
		packet::MULTICAST_2  := 2,
		packet::MULTICAST_3  := 2,
		packet::BROADCAST    := 1
	  };
	}

	function new(string n, component_base p=null);
	  super.new(n,p);
	  port_index = 0;
	endfunction

	task get_next_packet(output packet p);
	  if (!this.randomize()) begin
		$fatal(0, "[%s] Sequencer randomization failed!", pathname());
	  end

	  // Create a new packet with correct source based on port_index
	  p = new($sformatf("%s.pkt", pathname()), port_index);

	  // Randomize packet fields with type-specific constraints
	  case (type_to_generate)
		packet::SINGLE: begin
		  if (!p.randomize() with { $countones(target) == 1; }) begin
			$fatal(0, "[%s] Packet randomization failed (SINGLE)", pathname());
		  end
		end

		packet::MULTICAST_2: begin
		  if (!p.randomize() with { $countones(target) == 2; }) begin
			$fatal(0, "[%s] Packet randomization failed (MULTICAST_2)", pathname());
		  end
		end

		packet::MULTICAST_3: begin
		  if (!p.randomize() with { $countones(target) == 3; }) begin
			$fatal(0, "[%s] Packet randomization failed (MULTICAST_3)", pathname());
		  end
		end

		packet::BROADCAST: begin
		  if (!p.randomize() with { target == 4'b1111; }) begin
			$fatal(0, "[%s] Packet randomization failed (BROADCAST)", pathname());
		  end
		end

		default: begin
		  if (!p.randomize()) begin
			$fatal(0, "[%s] Packet randomization failed (DEFAULT)", pathname());
		  end
		end
	  endcase

	  $display("[%s] Generated: Src=%b Tgt=%b Data=%02h Type=%s",
			   pathname(), p.source, p.target, p.data, p.type_enum.name());
	endtask
  endclass