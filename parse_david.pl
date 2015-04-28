
# Get options with switches
use Getopt::Std;

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

# Create verilog netlist object
$net_list = new Verilog::Netlist(options => $option);

getopts("f:l:d:s:i:o:V", \%myargs);

# Check command line options & set file_list & directory_list file handles
&setOptions ();

# Read dir list
$option = &incDirList ($directory_list);

#######Checking is done###########
# Iterate through all signals of the top module and construct the in and out port objects
&iteratePorts ($top_module, \@single_bit_in_ports, \@top_module_ports, \@in_ports, \@out_ports, \@inout_ports, \$total_in, \$total_out);

#use Data::Dumper;
#print Dumper(@top_module_ports);

# Check 2: No inout ports
if (scalar(@inout_ports) > 0) {
  print "<strong>Check 2: <span class=\"failure\">Failure!!</span></strong> [ Top module has inout type ports ]\n";
        exit (1);
}

# Check 2: Success
print "<strong>Check 2: <span class=\"success\">Success!!</span></strong> [ Top module has no inout type ports ]\n";

# Check 3: At least one or more 1-bit input ports
if (scalar(@single_bit_in_ports) == 0) {
  print "<strong>Check 3: <span class=\"failure\">Failure!!</span></strong> [ Top module needs at least one 1-bit input port to function as the clock pin ]\n";
        exit (1);
}

# Check 3: Success
print "<strong>Check 3: <span class=\"success\">Success!!</span></strong> [ Top module has one or more 1-bit ports to function as the clock pin ]\n";


# Print the name of the 1-bit input pins
$_c = 0;
print "\n<strong>Select the clock signal for the top module from below:</strong>\n";
foreach $one_bit_pin (@single_bit_in_ports)
 {
       $_c++;
       print "#".$_c.". ".$one_bit_pin."\n";
}

exit(0);



##### Sub Routines follow #####

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

# Check and return top module in netlist
# Displays error & exits if more than 1 top module is found
# Parameters: [0]: Verilog::Netlist Object
# Return: Top module Verilog::Netlist::Module object
sub checkTopModule {
	my ($nl) = @_;
	my @top_modules = $nl->top_modules_sorted();

	# Check number of top modules, exit if more than 1
	if (scalar(@top_modules) > 1) {
    print "<strong>Check 3: <span class=\"failure\">Failure!!</span></strong> [ Found more than 1 top module! ]\n";
	


	if ($verbose) {
			$_c = 0;
			for $module (@top_modules) {
				$_c++;
				print $_c.". <strong>".$module->name()."</strong>\n";
			}
		}
		exit (1);
	}

	# Return the '0'th top module
	$top_modules[0];
}

sub buildNetList {
	my ($nl) = @_;

	# Link & lint the netlist
	# Check 0: Files compile, netlist could be contructed
	if ($verbose) {
		print "\nGenerating verilog netlist..\n\n";
	}
	# Reference to netlist passed, need to dereference
	${$nl}->link();
	${$nl}->lint(); # Optional linting step

	# Allow warnings
	${$nl}->exit_if_error(allow=>'warning');
}

sub incFileList {
	my ($nl, $fh) = @_;

	# Read the filelist line by line
	@lines = <$fh>;
	foreach $line (@lines) {
		@words = split(/\s+/, $line);
		foreach $word (@words) {
			&addVerilogFile ($nl, $word);
		}
	}
	# Nothing to return
}

# Add verilog file to specified netlist
sub addVerilogFile {
	my ($nl, $fn) = @_;

	# Reference to netlist passed, need to dereference
	${$nl}->read_file(filename => $fn);
	${$nl}->exit_if_error(allow=>'warning');

  $_c = 0;
	# Store the modules
	for $module (${$nl}->modules()) {
    $_c++;
    if (($_c == 1) && $verbose) {
      print "Found following Verilog modules: \n";
    }
		if (!(exists $module_file_hash{$module->name()})) {
			if ($verbose) {
				print $_c.". <strong>".$module->name."</strong>\n";
			}
			$module_file_hash{$module->name()} = $fn;
		}
	}
	# No return
}

sub incDirList {
	my ($D) = @_;

	# Verilog options object
	my $opt = new Verilog::Getopt;

	# Include directory list if specified
	if ($D) {
		# Read directory list line-by-line
		@lines = <$D>;
		foreach $line (@lines) {
			# Each line can have multiple space-separated directories specified
			@words = split(/\s+/, $line);
			foreach $word (@words) {
				if ($verbose) {
					print "Including directory ".$word."\n";
				}
				$opt->incdir($word);
			}
		}
	}

	# Return option object;
	$opt;
}

# Check myargs array & sets global variables
# Parameters: None
# Return: None
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
  
  # Max. input / output ports
  if (exists $myargs{'i'} && $myargs{'i'} && (&is_int($myargs{'i'}) == 1)) {
    $max_in_ports = $myargs{'i'};
  } else {
    $max_in_ports = MAX_IN_PORTS;
  }
  if (exists $myargs{'o'} && $myargs{'o'} && (&is_int($myargs{'o'}) == 1)) {
    $max_out_ports = $myargs{'o'};
  } else {
    $max_out_ports = MAX_OUT_PORTS;
  }
  
	# Verbose mode or not
	if (exists $myargs{'V'}) {
		$verbose = 1;
	}
}

# Open a regular file and return file handle
# Parameters: 
# 	file name (with path)
# 	strict mode: if 1, will exit on any error, if 0 will only print warning
# Return: file handle
sub openFile {
	my ($fn, $strict) = @_;
	my $fh;

	# Check for existence, non-zero size and plain file
	if (! -s $fn || ! -f _) {
		if ($strict) {
			print STDERR "Error: Specified file ".$fn." does not exist or is of zero size!\n";
			exit (1);
		} else {
			print STDERR "Warning: Specified file ".$fn." will be ignored as it does not exist or is of zero size!\n";
		}
	} else {
		# Open the filelist and assign a file handle
		unless(open($fh,"<$fn")) {
			if ($strict) {
				print STDERR "Error: Could not open specified file $fn!\n";
				exit(1);
			} else {
				print STDERR "Warning: Specified file ".$fn." will be ignored as it could not be opened!\n";
			}
		}
	}

	# Return the file handle
	$fh;
}

# Print usage of the perl script
# Parameters: None
# Return: None
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

# Close all open File Handles
# Parameters: None
# Return: None
sub closeFileHandles {
	if ($file_list) {
		close($file_list);
	}
	if ($directory_list) {
		close($directory_list);
	}
}

# Check is a scalar is a +ve integer
sub is_int {
  my ($var) = @_;

  if (($var != 0) && ($var =~ /^\d+$/)) {
    return 1;
  }
  
  return 0;
}


