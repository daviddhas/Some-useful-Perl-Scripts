#!/usr/bin/perl

#This Perl script reads through the top module and the submodules in a Verilog file 
#It returns the Port Direction (input/output/inout) as well as the Port Names
#TO DO : Get arguments from the user to acess Verilog files from specific file locations

use strict;
use warnings;
use Verilog::Netlist;

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
