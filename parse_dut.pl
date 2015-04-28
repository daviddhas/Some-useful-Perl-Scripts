#!/usr/bin/perl
#
# Parse user DUT verilog files & check for required conditions & return stuff
#
# Usage: parse_dut.pl -f <verilog file>|-l <verilog file list> [-d <directory list>] [-V]
# Options:
# 	-l <file list> : File containing names of the user DUT verilog file
#		-f <file> : Verilog file containing user DUT
# 	-d <directory list>: [Optional] List of directories to search for verilog files
#   -s <session db id>: The session_id in the db
#   -i <max input ports>: max permitted number of input ports
#   -o <max output ports>: max permitted number of output ports
# 	-V : [Optional] Verbose output

# Get options with switches
use Getopt::Std;
# VerilogPerl modules
use Verilog::Netlist;
use Verilog::Getopt;
# Mysql Database modules
use DBI;
# Perl JSON
use JSON;
# Base64 encode decode
use MIME::Base64;

# Constants
use constant MAX_IN_PORTS => 16;
use constant MAX_OUT_PORTS => 16;
# Mysql details
use constant MYSQL_HOST => 'localhost';
use constant MYSQL_DB => 'ipi_vlab_p';
use constant MYSQL_USER => 'ipiadmin';
use constant MYSQL_PASS => '(HqZ!$.W~=N+';
use constant SESS_DUT_TABLE => 'dsi_sessions_dut_data';

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
my $max_in_ports = 0; # Max. number of permitted input ports
my $max_out_ports = 0; # Max. number of permitted output ports
my $total_in = 0; # Total number of input pins
my $total_out = 0; # Total number of output pins
my $sessin_db_id; # session_d against whoich the dut data will be stored in DB

getopts("f:l:d:s:i:o:V", \%myargs);

# Check command line options & set file_list & directory_list file handles
&setOptions ();

# Read dir list
$option = &incDirList ($directory_list);

# Create verilog netlist object
$net_list = new Verilog::Netlist(options => $option);

# Check 0: Check all files compile, etc.
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

# Check 0: Success
if ($file) {
  print "<strong>Check 0: <span class=\"success\">Success!!</span></strong> [ Uploaded Verilog file has no errors ]\n";
} elsif ($file_list) {
  print "<strong>Check 0: <span class=\"success\">Success!!</span></strong> [ Verilog files in filelist have no errors ]\n";
}

# Check 1: Check that only 1 top module
$top_module = &checkTopModule ($net_list);

# Print top module
if ($verbose) {
  print "\nTop Module: <strong>".$top_module->name."</strong>\n";
}

# Check 1: Success
if ($file) {
  print "<strong>Check 1: <span class=\"success\">Success!!</span></strong> [ Uploaded Verilog file has only one top module: ".$top_module->name." ]\n";
} elsif ($file_list) {
  print "<strong>Check 1: <span class=\"success\">Success!!</span></strong> [ Uploaded Verilog file has only one top module: ".$top_module->name." ]\n";
}

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

# Check 4: Total no. of input ports <= (<max input ports> + 1)
if (scalar($total_in) > ($max_in_ports + 1)) {
  print "<strong>Check 4: <span class=\"failure\">Failure!!</span></strong> [ Total number of input pins cannot be greater than ".($max_in_ports+1)." ]\n";
	exit (1);
# Check 5: Total no. of output ports < <max output ports>
} elsif ($total_out > $max_out_ports) {
  print "<strong>Check 4: <span class=\"failure\">Failure!!</span></strong> [ Total number of output pins cannot be greater than ".$max_out_ports." ]\n";
	exit (1);
} 

# Check 4: Success
print "<strong>Check 4: <span class=\"success\">Success!!</span></strong> [ Top module has valid number of total input and output pins ]\n";

print "\n<strong><span class=\"success bigfont\">*** All checks passed ***</span></strong>\n";

# Finally store module details in DB
&persist_dut_details ($sessin_db_id, $top_module->name, $total_in, $total_out, \@single_bit_in_ports, \@top_module_ports);

# Print the name of the 1-bit input pins
#$_c = 0;
#print "\n<strong>Select the clock signal for the top module from below:</strong>\n";
#foreach $one_bit_pin (@single_bit_in_ports) {
#	$_c++;
#	print "#".$_c.". ".$one_bit_pin."\n";
#}

exit(0);

########### Main script Ends ############

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

# Mysql store dut details
sub persist_dut_details {
  my ($sid, $tname, $tin, $tout, $sbits, $tps) = @_;
  
  # Prepare values for storing into DB
  my $json = new JSON;
  $json->allow_nonref();
  my $_sbits = encode_base64($json->encode(\@{$sbits}));
  my $_tps = encode_base64($json->encode (\@{$tps}));

  $dbh = DBI->connect('dbi:mysql:'.MYSQL_DB,MYSQL_USER,MYSQL_PASS)
    or die 'Error: Could not connect to Database\n';
  
  # If row exists update, or else insert
  $chk_sql = 'SELECT * FROM `'.SESS_DUT_TABLE.'` WHERE `session_id` = ?';
  $chk = $dbh->prepare($chk_sql);
  $chk->execute($sid)
    or die 'SQL Query : '.$chk_sql.' | SQL Error: '.$DBI::errstr."\n";
  if ($chk->rows == 0) {
    $ins_sql = 'INSERT INTO `'.SESS_DUT_TABLE.'` '.
      '(`session_id`, `top_module`, `total_in`, `total_out`, `1bit_ports`, `all_ports`) '.
      'VALUES (?,?,?,?,?,?)';
    $ins = $dbh->prepare($ins_sql);
    $ins->execute($sid, $tname, $tin, $tout, $_sbits, $_tps)
      or die 'SQL Query : '.$ins_sql.' | SQL Error: '.$DBI::errstr."\n";
  } else {
    $upd_sql = 'UPDATE `'.SESS_DUT_TABLE.'` SET `top_module` = ?, '.
    '`total_in` = ?, `total_out` = ?, `1bit_ports` = ?, `all_ports` = ? '.
    'WHERE `session_id` = ?';
    $upd = $dbh->prepare($upd_sql);
    $upd->execute($tname, $tin, $tout, $_sbits, $_tps, $sid)
      or die 'SQL Query : '.$upd_sql.' | SQL Error: '.$DBI::errstr."\n";
  }

}