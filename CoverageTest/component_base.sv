class component_base;
	string name; component_base parent;
	function new(string name, component_base parent=null);
	  this.name=name; this.parent=parent;
	endfunction
	function string pathname();
	  if(parent==null) return name;
	  else return {parent.pathname(),".",name};
	endfunction
	function void print(); $display("Component: %s", pathname()); endfunction
  endclass