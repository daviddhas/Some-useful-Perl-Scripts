#!/usr/bin/perl

#Script to write a test bench for the top module in from the files provided

#use strict;
#use warnings;
use Verilog::Netlist;

# Prepare the netlist for a given file 
# TO DO : Substitute with the Session id and the uploader_dut.v file that the user uploads in the VLABs website
if(@ARGV < 4){
print "./makeTestbench.pl <modfile1> .. <modfilen> alwaysBlockFile clkSignal clkModifier\n";
print "example:\t ./makeTestbench.pl counter.v counter2.v alwaysBlockfile.txt clk negedge\n";
exit 0;
}
my $clkModifier = pop @ARGV;
chomp $clkModifier;
my $clkSignal = pop @ARGV;
if($clkSignal eq '0'){$clkSignal = '*';$clkModifier = '';}
elsif($clkModifier eq '0'){$clkModifier ="";}
else {$clkModifier.=" ";}
my $alwaysBlockFileName = pop @ARGV;

print "$clkModifier\n$clkSignal\n$alwaysBlockFileName\n";

my $nl = new Verilog::Netlist();
foreach (@ARGV){
	$nl->read_file(filename => $_);
		}
#The above command parses the Verilog file into a hash of ports, signals and instantiations

$nl->link();
$nl->lint();
$nl->exit_if_error();

my $topModule;
my $topModuleName;
my $inVarString;
my $inFmtString;
my $odinInString;
my $outVarString;
my $outFmtString;
my $odinOutString;
my %inputPorts;
my %outputPorts;
my $optString;
my $initString;
my $alwaysString;
my $portDecl;
my $instString;
my @topModules;#stores references for all the top modules
my %topModuleInst;#stores instantization strings for all the top modules 
for my $mod ( $nl->modules_sorted_level() ) {
if ($mod->is_top()){
		print "Module Name:\t ".${mod}->name()."\n" ;
		print "Level:\t\t".$mod->level(),"\n";
		$topModuleName = $mod->name();
		$topModule = $mod;
		push @topModules, $mod;
			}
}
#print $fileName, $ARGV[0], "\n";
open(my $tbh, ">", "${topModuleName}_tb.v") or die "cannot open > ${topModuleName}_tb.v: $!";
 
foreach my $topModule(@topModules){
my $inputString;
foreach ($topModule->ports())
	{
		if($_->direction() =~ /in/)
		{
		$inputPorts{$_->name()} = $_->data_type();
		print $_->name(), "\t", $_->data_type(), "\n";
			} 
		elsif($_->direction() =~ /out/)
		{
		$outputPorts{$_->name()} = $_->data_type();
		print $_->name(), "\t", $_->data_type(),"\n";
			}
	}
 	print "The input ports are ", keys %inputPorts, "\n";
	print "The output ports are ", keys %outputPorts, "\n";

#options string for instantization of the module; and port declarations string;
foreach (keys %inputPorts){
			$portDecl .= "reg ".$inputPorts{$_}." ${_};\n";
			$inputString .= "\.${_}\(${_}\)\, ";
{
		if($inVarString)
		{
			$inVarString =join(' ,', $inVarString, $_);}
		else 
		{
			$inVarString = $_;}
		#print $port->name()."\n";
		
		if($inFmtString)
		{
			$inFmtString =join(' ', $inFmtString,"\%b\\t");}
		else 
		{	
			$inFmtString = "\%b\\t";}
		

		if($odinInString)
		{
			$odinInString =join(' ', $odinInString, $_."\\t");}
		else 
		{	
			$odinInString = $_."\\t";}
		
		}
		}

foreach (keys %outputPorts){
		$portDecl .= "wire ".$outputPorts{$_}." ${_};\n";
		$inputString .= "\.${_}\(${_}\)\, ";
if($outVarString)
		{
			$outVarString =join(',', $outVarString, $_);}
		else 
		{
			$outVarString = $_;}
		#print $port->name()."\n";
		
		if($outFmtString)
		{
			$outFmtString =join(' ', $outFmtString,"\%b\\t");}
		else 
		{	
			$outFmtString = "\%b\\t";}
		if($odinOutString)
		{
			$odinOutString =join(' ', $odinOutString, $_."\\t");}
		else 
		{	
			$odinOutString = $_."\\t";}
		
		}

	$topModuleInst{$topModule} = $inputString;
}

#concat instantizations
for(@topModules)
{
chop $topModuleInst{$_};chop $topModuleInst{$_};
$instString.=$_->name." DUT".$_->name."(".$topModuleInst{$_}.");\n";
}


my $finishString;
if(-e $alwaysBlockFileName){open ALWAYSBLOCK, '<', $alwaysBlockFileName or die "could not open file :$!\n";
for(<ALWAYSBLOCK>){$alwaysString.=$_;print;}
if(!($alwaysString =~ /\$finish/)){$finishString="#100 \$finish;\n";}
close ALWAYSBLOCK;
}
print "The finish string is $finishString \n";
#Print Verilog Testbench file       
print $alwaysString;
print $tbh <<ENDTB;
//auto generated testbench from makeTestBench.pl
module ${topModuleName}_tb ();
//port declarations	
$portDecl

//device instantisation //MUST EXTEND FOR MULTIPLE INSTANTIZATIONS
$instString
integer infh, outfh;
initial begin
infh = \$fopen("inputvectors.txt", "w");
outfh = \$fopen("outputvectors.txt","w");
\$fwrite(infh, \"${odinInString}\\n\");
\$fwrite(outfh, \"${odinOutString}\\n\");	
$finishString
end
//always block
always \@(${clkModifier}$clkSignal)begin
\$fwrite\(infh, \"$inFmtString\\n\", $inVarString\);
\$fwrite\(outfh, \"$outFmtString\\n\", $outVarString\);
$alwaysString
end

endmodule

ENDTB
