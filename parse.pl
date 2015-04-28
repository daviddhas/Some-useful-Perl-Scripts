#!/usr/bin/perl

#The script accepts input Verilog file and prints the input ports in the Verilog File
# Usage: parse_dut.pl -V <verilog file>



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

getopt("V", \%myargs);

# Include verilog file or files from filelist
if ($file) {
	&addVerilogFile (\$net_list, $file);
} elsif ($file_list) {
	&incFileList (\$net_list, $file_list);
}

# Check 0: Net list is build successfuly
&buildNetList (\$net_list);

# Close all opened file handles
&closeFileHandles ();

#Print the one bit pins

foreach $one_bit_pin (@single_bit_in_ports)
{
       $_c++;
       print "#".$_c.". ".$one_bit_pin."\n";
}

exit(0);



####################### SUB ROUTINES FOLLOW ##################################################################################
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

sub buildNetList {
	my ($nl) = @_;

	# Link & lint the netlist
	# Check 0: Files compile, netlist could be contructed
	if ($verbose) {
		print "\nGenerating verilog netlist..\n\n";
	}
	# Reference to netlist passed, need to dereference
	#${$nl}->link();
	${$nl}->lint(); # Optional linting step

	# Allow warnings
	${$nl}->exit_if_error(allow=>'warning');
}



sub closeFileHandles {
	if ($file_list) {
		close($file_list);
	}
	if ($directory_list) {
		close($directory_list);
	}
}

sub setOptions {
# single verilog file or a verilog filelist is compulsory
	if (exists $myargs{'f'} && $myargs{'f'} && length($myargs{'f'})) {
		&openFile ($myargs{'f'}, 1);
		$file = $myargs{'f'};
	}
	else {
		print STDERR "Error: Please specify a verilog filename or a filelist filename!\n";
		&printUsage;
	}
	}
sub printUsage {
	print "\nUsage: parse.pl -v <verilog file>";
	exit (1);
}
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