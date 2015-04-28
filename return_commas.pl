#!/usr/bin/perl

#This Perl script reads through the top module and the submodules in a Verilog file 
#It returns the Port Direction (input/output/inout) as well as the Port Names
#TO DO : Get arguments from the user to acess Verilog files from specific file locations

#use strict;
#use warnings;
use Verilog::Netlist;


use feature qw(say switch);
#use Getopt::Long;
# Prepare the netlist for a given file 
# TO DO : Substitute with the Session id and the uploader_dut.v file that the user uploads in the VLABs website
$file_name=$ARGV[0];
my $nl = new Verilog::Netlist();
$nl->read_file(filename => $file_name);

# Read through the  sub modules
$nl->link();   #Resolves references between the different modules
$nl->lint();   #Error checks the entire netlist structure
$nl->exit_if_error();

my @input_ports;


for my $mod ( $nl->modules() ) {
   #print "\nSuccess : Uploaded Verilog file has only one top module:\n";
   #print $mod->name(), "\n";
   #print "<strong>Check 1: <span class=\"success\">Success!!</span></strong> Uploaded Verilog file has only one top module:" $mod->name(), "\n" ;
}
print "\n";
																				

for my $mod ( $nl->top_modules_sorted() ) {

@input_ports = show_port_names_directions($mod, '', '', '');
# print "\n  The input ports are @input_ports\n";

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
   #print "${indent}Module Name = ", $mod->name(), "  Hierarchial Instation Name = $hier\n \n";
   $indent = '';

   #PRINT ALL INPUT PORTS
   for my $sig ($mod->ports_sorted()) {
	#print $indent, 'Port Direction=', sigdir($sig->direction()), ' Port Name=', $sig->name(), "\n";	
       if (sigdir($sig->direction()) eq 'input'){
           if ($indent ne '') {
               $indent .= ',';
           }
           $indent .= $sig->name();
       }
   }
   @temp_array = $indent;
   @temp_array1= sort { lc($a) cmp lc($b) } @temp_array;
   say @temp_array1;
   say $indent;
}
        
  
