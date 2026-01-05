class checker extends component_base;

// Expected from each source VC (driver)
mailbox #(packet) exp_mb[4];

// Actual from each output VC (monitor)
mailbox #(packet) act_mb[4];

typedef struct {
  packet pkt;
  time   exp_time;
} exp_entry_t;

// Updated expected list per destination
exp_entry_t exp_list[4][$]; // queue per dst port

int pass_cnt   = 0;
int fail_cnt   = 0;
int exp_total  = 0;

function new(string n, component_base p=null);
  super.new(n,p);
endfunction

function void connect_exp(int src, mailbox #(packet) mb);
  exp_mb[src] = mb;
endfunction

function void connect_act(int port, mailbox #(packet) mb);
  act_mb[port] = mb;
endfunction

function automatic packet clone_packet(packet p);
  packet c = new(p.name);
  c.source = p.source;
  c.target = p.target;
  c.data   = p.data;
  c.post_randomize();
  return c;
endfunction

// Collect expected packets and timestamp them
task exp_dispatch();
  packet p;
  forever begin
	bit got = 0;
	for (int s=0; s<4; s++) begin
	  if (exp_mb[s] != null && exp_mb[s].try_get(p)) begin
		got = 1;
		for (int d=0; d<4; d++) begin
		  if (p.target[d]) begin
			exp_entry_t entry;
			entry.pkt = clone_packet(p);
			entry.exp_time = $time;
			exp_list[d].push_back(entry);
			exp_total++;
		  end
		end
	  end
	end
	if (!got) #1;
  end
endtask

// Match incoming packet to expected list
function automatic bit match_and_remove(int dst, packet act);
  for (int i=0; i<exp_list[dst].size(); i++) begin
	packet e = exp_list[dst][i].pkt;
	if (e.source === act.source &&
		e.target === act.target &&
		e.data   === act.data) begin
	  exp_list[dst].delete(i);
	  return 1;
	end
  end
  return 0;
endfunction

task check_port(int dst);
  packet act;
  forever begin
	act_mb[dst].get(act);
	act.post_randomize();
	
	if (match_and_remove(dst, act)) begin
	  pass_cnt++;
	  $display("[CHK] PASS dst%0d: Src=%b Tgt=%b Data=%02h Time=%0t", dst, act.source, act.target, act.data, $time);
	end else begin
	  fail_cnt++;
	  $display("[CHK] FAIL dst%0d UNEXPECTED: Src=%b Tgt=%b Time=%0t", dst, act.source, act.target, act.data, $time);
	end
  end
endtask

task run();
  fork
	exp_dispatch();
	check_port(0);
	check_port(1);
	check_port(2);
	check_port(3);
  join_none
endtask

function automatic int calc_missing();
  int missing = 0;
  for (int d=0; d<4; d++) missing += exp_list[d].size();
  return missing;
endfunction

function automatic int calc_exp_mb_pending();
  int pending = 0;
  for (int s=0; s<4; s++) begin
	if (exp_mb[s] != null) pending += exp_mb[s].num();
  end
  return pending;
endfunction

// Print missing packet details
task report_missing_details();
  for (int d = 0; d < 4; d++) begin
	foreach (exp_list[d][i]) begin
	  packet e = exp_list[d][i].pkt;
	  time t   = exp_list[d][i].exp_time;
	  $display("[CHK][MISSING] dst%0d: Src=%b Tgt=%b Data=%02h  Expected@%0t",
				d, e.source, e.target, e.data, t);
	end
  end
endtask

task report_and_assert();
  int missing;
  int exp_pending;

  int max_loops = 5000;
  int loops     = 0;

  do begin
	missing     = calc_missing();
	exp_pending = calc_exp_mb_pending();

	if ((missing == 0) && (exp_pending == 0)) break;
	#10;
	loops++;
  end while (loops < max_loops);

  missing     = calc_missing();
  exp_pending = calc_exp_mb_pending();

  $display("\n==== CHECKER SUMMARY ====");
  $display("EXPECTED_TOTAL=%0d  RECEIVED=%0d  PASS=%0d  FAIL=%0d  MISSING=%0d  EXP_MB_PENDING=%0d",
		   exp_total, (pass_cnt + fail_cnt), pass_cnt, fail_cnt, missing, exp_pending);

  if (missing != 0) begin
	$display("\n==== MISSING PACKET DETAILS ====");
	report_missing_details();
  end

  if (fail_cnt != 0)      $fatal(0, "Checker found FAILs.");
  if (missing  != 0)      $fatal(0, "Checker found MISSING expected packets.");
  if (exp_pending != 0)  $fatal(0, "Checker still has expected packets pending in mailboxes.");
endtask

endclass
