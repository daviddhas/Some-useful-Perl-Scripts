# VerilogPerl modules
use Verilog::Netlist;
use Verilog::Getopt;

# Global Variables
my $option; # Verilog::Getopt object
my $net_list; # Verilog::Netlist object
my $top_module; # Verilog::Module top module object
my @top_module_ports; # Array containing ports information
my @single_bit_in_ports = (); # Array of 1-bit input port names
my @in_ports = (); # Array of all input ports Verilog::Module::Port objects
my @out_ports = (); # Array of all output ports Verilog::Module::Port objects
my @inout_ports = (); # Array of all inout ports Verilog::Module::Port objects


getopts("V", \%myargs);

&iteratePorts ($top_module, \@single_bit_in_ports, \@top_module_ports, \@in_ports, \@out_ports, \@inout_ports, \$total_in, \$total_out);

#Print the one bit pins

foreach $one_bit_pin (@single_bit_in_ports)
{
       $_c++;
       print "#".$_c.". ".$one_bit_pin."\n";
}

exit(0);



#####  Subroutines Begin ########
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






sub setOptions {
  # Session DB id is compulsory
	if (exists $myargs{'s'} && $myargs{'s'} && (&is_int($myargs{'s'}) == 1)) {
    $sessin_db_id = $myargs{'s'};
  } else {
		print STDERR "Error: Invalid Session ID!\n";
		&printUsage;  
  }
  
	# single verilog file or a verilog filelist is compulsory
	if (exists $myargs{'f'} && $myargs{'f'} && length($myargs{'f'})) {
		&openFile ($myargs{'f'}, 1);
		$file = $myargs{'f'};
	} elsif (exists $myargs{'l'} && $myargs{'l'} && length($myargs{'l'})) {
		$file_list = &openFile ($myargs{'l'}, 1);
	} else {
		print STDERR "Error: Please specify a verilog filename or a filelist filename!\n";
		&printUsage;
	}

	# Directory list is not compulsory
	if (exists $myargs{'d'} && $myargs{'d'} && length($myargs{'d'})) {
		$directory_list = &openFile ($myargs{'d'}, 0);
	}
  
sub printUsage {
	print "\nUsage: parse_dut.pl -f <verilog file>|-l <verilog file list> [-d <directory list>] [-V]\n".
				"Options:\n".
				"    -f <file> : Verilog file containing user DUT\n".
				"    -l <filelist> : File containing names of the user DUT verilog file\n".
				"    -d <directory list>: [Optional] List of directories to search for verilog files\n".
        "    -s <session db id>: integer session_id in the db\n".
        "    -i <max input ports>: [Optional (default: 16)] max permitted number of input ports\n".
        "    -o <max output ports>: [Optional (default: 16)] max permitted number of output ports\n".
				"    -V : [Optional] Provide verbose output\n";
	exit (1);
}
