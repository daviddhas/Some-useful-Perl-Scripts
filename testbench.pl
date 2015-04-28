#!/usr/bin/perl

#This Perl script reads through the Test Bench (a Verilog file) 
#It returns the input vectors in the form acceptable to ODIN

#use strict;
#use warnings;
use Verilog::Netlist;

# Prepare the netlist for a given file 
# TO DO : Substitute with the Session id and the uploader_dut.v file that the user uploads in the VLABs website
$file_name=$ARGV[0];
my $nl = new Verilog::Netlist();
$nl->read_file(filename => $file_name);
#The above command parses the Verilog file into a hash of ports, signals and instantiations

my @input_ports;

for my $mod ( $nl->top_modules_sorted() ) {
@input_ports = show_port_names_directions($mod, '', '', '');

}


########################################SUB ROUTINES #################################################################################
sub sigdir {
   # Change "in"  to "input" and "out" to "output"
   my $dir = shift;
   return ($dir eq 'inout') ? $dir: $dir . 'put';
}

sub show_port_names_directions {
   # Recursively descend through module hierarchy,
   # printing each module name and full hierarchical
   # specifier, all module port names, and all
   # instance port connections.
   my $mod      = shift;
   my $indent   = shift;
   my $hier     = shift;
   my $cellname = shift;
   my @inputs;
   my @temp_array;
   my @temp_array1;
   if ($cellname) {
       $hier .= ".$cellname";
   }
   else {	
       $hier = $mod->name();
   }
#   print "${indent}Module Name = ", $mod->name(), "  Hierarchial Instation Name = $hier\n \n";
   print "Module Name = ", $mod->name(), "  Hierarchial Instation Name = $hier\n \n";
	open (my $fh1, ">testbench_maker.v");
  	 print $fh1 "module tb_", $mod->name(),";\n";
#   $indent .= '   ';

   #PRINT ALL PORTS
   for my $sig ($mod->ports_sorted()) {
	print $indent, 'Port Direction=', sigdir($sig->direction()), ' Port Name=', $sig->name(), "\n";	
       if (sigdir($sig->direction()) eq 'input'){
	print $fh1 "reg ", $sig->name(), ";\n";}
	else{
#      elsif (sigdir($sig->direction()) eq 'input'){
	print $fh1 $indent, "wire ", $sig->name(), ";\n";
#	print $fh1 $indent, sigdir($sig->direction()) ," ", $sig->name(), ";\n";	 
}}

print "The Test Bench is created successfully and named as testbench_maker.v\n";
print $fh1 "\n";
print($fh1 "tb_", $mod->name()," ",$mod->name(),"( \n");	

@ports_sorted1=$mod->ports_sorted();
$numberOfPorts = scalar $#ports_sorted1;

$port_count = 0;
for my $sig (@ports_sorted1) {
	print $fh1 $indent,".",$sig->name(), "(", $sig->name(),")";
    if ($numberOfPorts == $port_count) {
        print $fh1 ");\n";
    }
    else {
        print $fh1 ",\n";
    }
    $port_count++;
}
print $fh1 "\n initial \n begin\n";

   for my $sig ($mod->ports_sorted()) {
	print $fh1 $indent, $sig->name(), "=0;\n";	 
}
print $fh1 "\n end";

print $fh1 "\n always \n #5 clk = !clk;\n endmodule \n";
close $fh1;

return (@inputs);
}
        
  
