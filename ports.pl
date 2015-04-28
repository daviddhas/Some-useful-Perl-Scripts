#!/usr/bin/perl
use strict;
use IO::File;

if(@ARGV < 1){
print "./ports.pl Verilog file name\n";
print "example:\t ./ports.pl counter.v \n";
exit 0;
}

use constant FILE => "@ARGV[0]";
use constant FIND => 'input wire';

IO::File->input_record_separator(FIND);

my $fh = IO::File->new(FILE, O_RDONLY)
  or die 'Could not open file ', FILE, ": $!";

$fh->getline;  #fast forward to the first match

#print each occurence in the file
print IO::File->input_record_separator
  while $fh->getline;

$fh->close;

