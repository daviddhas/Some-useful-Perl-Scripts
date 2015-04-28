#!/usr/bin/perl

#This Perl script reads through the top module and the submodules in a Verilog file 
#It returns the Port Direction (input/output/inout) as well as the Port Names
#TO DO : Get arguments from the user to acess Verilog files from specific file locations

use strict;
use warnings;
use Verilog::Netlist;
use Verilog::Getopt;

# Global Variables
my %myargs; # Command-line arguments hash
my $verbose = 0; # Verbose mode
my %module_file_hash = (); # Stores filenames against contained Verilog modules
my $option; # Verilog::Getopt object
my $net_list; # Verilog::Netlist object
my $top_module; # Verilog::Module top module object
my @top_module_ports; # Array containing ports information
my @single_bit_in_ports = (); # Array of 1-bit input port names
my @in_ports = (); # Array of all input ports Verilog::Module::Port objects
my @out_ports = (); # Array of all output ports Verilog::Module::Port objects
my @inout_ports = (); # Array of all inout ports Verilog::Module::Port objects


# Prepare the netlist for a given file 
# TO DO : Substitute with the Session id and the uploader_dut.v file that the user uploads in the VLABs website
my $nl = new Verilog::Netlist();
$nl->read_file(filename => './upcounter.v');


# Read through the  sub modules
$nl->link();   #Resolves references between the different modules
$nl->lint();   #Error checks the entire netlist structure
$nl->exit_if_error();

print "\n\nModule names in netlist:\n";


for my $mod ( $nl->modules() ) {
   print $mod->name(), "\n";
}
print "\n";

for my $mod ( $nl->top_modules_sorted() ) {
   show_hier($mod, '', '', '');
}

# Check 1: Check for upload errors
if ($nl) {
  print "<strong>Check 1: <span class=\"success\">Success!!</span></strong> [ Uploaded Verilog file has only one top module: ".$top_module->name." ]\n";
} else
{ exit(1);
}

# Iterate through all signals of the top module and construct the in and out port objects
&iteratePorts ($top_module, \@single_bit_in_ports, \@top_module_ports, \@in_ports, \@out_ports, \@inout_ports, \$total_in, \$total_out);



# Check 2 :No inout ports
if (scalar(@inout_ports) > 0) {
  print "<strong>Check 2: <span class=\"failure\">Failure!!</span></strong> [ Top module has inout type ports ]\n";
	exit (1);
} else {
print "<strong>Check 2: <span class=\"success\">Success!!</span></strong> [ Top module has no inout type ports ]\n";
}


# Check 3: Success
print "<strong>Check 3: <span class=\"success\">Success!!</span></strong> [ Top module has one or more 1-bit ports to function as the clock pin ]\n";



# Check 4: Total no. of input ports 
  print "<strong>Check 4: <span class=\"failure\">Failure!!</span></strong> [ Total number of input pins cannot be greater than ".($max_in_ports+1)." ]\n";
	
	
	
# Check 5: Total no. of output ports 
  print "<strong>Check 4: <span class=\"failure\">Failure!!</span></strong> [ Total number of output pins cannot be greater than ".$max_out_ports." ]\n";
	exit (1);
}




































#######################################################SUBROUTINES FOLLOW ################################################

sub show_hier {
   # Recursively descend through module hierarchy,
   # printing each module name and full hierarchical
   # specifier, all module port names, and all
   # instance port connections.
   my $mod      = shift;
   my $indent   = shift;
   my $hier     = shift;
   my $cellname = shift;
   if ($cellname) {
       $hier .= ".$cellname";
   }
   else {
       $hier = $mod->name();
   }
   print "${indent}Module Name = ", $mod->name(), "  Hierarchial Instation Name = $hier\n \n";
   $indent .= '   ';

   for my $sig ($mod->ports_sorted()) {
       print $indent, 'PortDir=', sigdir($sig->direction()), ' PortName=', $sig->name(), "\n";
   }

   for my $cell ($mod->cells_sorted()) {
       for my $pin ($cell->pins_sorted()) {
           print $indent, ' CellName=', $cell->name(), ' PinName=', $pin->name(),' NetName=', $pin->netname(), "\n";
       }

       show_hier($cell->submod(), $indent, $hier, $cell->name()) if $cell->submod();
   }
}

sub sigdir {
   # Change "in"  to "input" and "out" to "output"
   my $dir = shift;
   return ($dir eq 'inout') ? $dir : $dir . 'put';
}

sub iteratePorts {
	my ($tmod, $spis, $tps, $inps, $outps, $inoutps, $tin, $tout) = @_;
	my %tmod_p;

	$_c = 0;
	for $port ($tmod->ports_ordered()) {
		$_c++;
    if (($_c == 1) && $verbose) {
      print "\nFound following ports in the top module:\n";
    }
		if ($verbose) {
			print $_c.". <strong>".$port->name. ($port->net->msb ? ("\t[".$port->net->msb.":".$port->net->lsb."]") : "\t[1-bit]")."\t".$port->direction."</strong>\n";
		}

    # Push into the ports hash
    push (@{$tps}, {'n' => $port->name, 'd' => $port->direction, 'msb' => int($port->net->msb), 'lsb'=> int($port->net->lsb)});
    
		if ($port->direction eq "in") {
				push (@{$inps}, $port);
				if ($port->net->msb) {
					${$tin} += ($port->net->msb - $port->net->lsb + 1);
				} else {
					${$tin}++;
					push (@{$spis}, $port->name);
				}
		} elsif ($port->direction eq "out") {
				push (@{$outps}, $port);
				if ($port->net->msb) {
					${$tout} += ($port->net->msb - $port->net->lsb + 1);
				} else {
					${$tout}++;
				}
				break;
		} elsif ($port->direction eq "inout") {
				push (@{$inoutps}, $port);
				break;
		} else {
				print "Default\n";
		}
	}

	if ($verbose) {
		print "\n";
	}

	# No return
}
