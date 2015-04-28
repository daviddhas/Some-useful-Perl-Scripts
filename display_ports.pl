#!/usr/bin/perl

use strict;
use warnings;
use Verilog::Netlist;

# prepare netlist
my $nl = new Verilog::Netlist();
$nl->read_file(filename => './top.v');

# read in any sub modules
$nl->link();
$nl->lint();
$nl->exit_if_error();

print "Module names in netlist:\n\n";


for my $mod ( $nl->modules() ) {
   print $mod->name(), "\n";
}
print "\n";

for my $mod ( $nl->top_modules_sorted() ) {
   show_hier($mod, '', '', '');
}

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
   print "${indent}ModuleName=", $mod->name(), "  HierInstName=$hier\n \n";
   $indent .= '   ';

   for my $sig ($mod->ports_sorted()) {
       print $indent, 'PortDir=', sigdir($sig->direction()), ' PortName=', $sig->name(), "\n";
   }
   for my $cell ($mod->cells_sorted()) {
       for my $pin ($cell->pins_sorted()) {
           print $indent, ' CellName=', $cell->name(), ' PinName=', $pin->name(),' NetName=', $pin->netname(), "\n";
       }
       show_hier($cell->submod(), $indent, $hier, $cell->name()) if $cell->submod();
	print "\n";
   }
}

sub sigdir {
   # Change "in"  to "input"
   # Change "out" to "output"
   my $dir = shift;
   return ($dir eq 'inout') ? $dir : $dir . 'put';
}
