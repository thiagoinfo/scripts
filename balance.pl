#!/usr/bin/perl
# ex: set tabstop=4: 
#
# balance.pl
# Requires Perl 5. Uses the POSIX function "floor".
#

=pod

=head1 NAME

balance.pl - Perl script for evenly distributing VDisk extents amongst MDisks.

=head1 VERSION

 @(#)08 1.12 SVCTools/examples/balance/balance.pl, cmpss_cust_scripts, cust_scripts 5/3/10 08:13:43

=head1 SYNOPSIS

B<balance.pl MDiskGrp> [-t VDisk,VDisk,...] [-m MDisk,MDisk,...] 
	[-n number] [-e] [-f [ all | partial | unstable ] [-r [delay] ] 
    -c cluster | -i ip [-k keyfile]	[-u username] [-s ssh] [-v]

B<balance.pl -h>

=head1 COPYRIGHT

Licensed Materials - Property of IBM
5639-VC3
© Copyright IBM Corp. 2006, 2010

=head1 DESCRIPTION

This script provides a solution to the problem of rebalancing the extents in an 
Managed Disk Group (MDiskGrp) after new media has been added to a heavily 
populated group.  The script uses available free space to shuffle extents until 
the number of extents from each VDisk on each MDisk is directly proportional to 
the size of the MDisk.

This script factors in currently running migrates and will not suggest any
operation that will clash.  On standard execution, the script provides a list
of migrates that can be executed concurrently, immediately.  The resulting 
changes will improve the balance of extents in the MDiskGrp.

In the event that the script is terminated, simply running it again with the
same parameters will result in the operation continuing as before.  It is not
necessary to wait for migrates to complete before running the script again.

=over 4

=item B<MDiskGrp>

Specify the name of the MDiskGrp to be balanced by this script.  If the script 
is unable to find this MDiskGrp by name, it will abort.

=item B<-t, --target VDisk,VDisk,...>

Specify a proper subset of VDisks that exist within the MDiskGrp to constrain 
the set of VDisks that will be balanced.  This can be used in combination with 
L<-m> to constrain both the MDisk and VDisk domains.  The script will attempt to
validate that these VDisks belong to the target MDiskGrp, and will abort if it 
finds that this is not the case.

=item B<-m, --media MDisk,MDisk,...>

By specifying a proper subset of MDisks from the MDiskGrp the script will only
balance the extents that exist within that subset.  This can be used in 
combination with L<-t> to constrain both the MDisk and VDisk domains.  The 
script will attempt to validate that these MDisks belong to the target MDiskGrp,
and will abort if it finds that this is not the case.

=item B<-n, --number migrates>

Constrain the number of migrates running on the SVC cluster.  If the number of 
actual migrates in operation is equal to or greater than this value, the script
will not spawn any more migrates.  If L<-r> is specified, the script will wait 
until existing migrates complete to spawn new migrates.  When L<-e> is not 
specified, this parameter limits the number of commands printed.

=item B<-e, -execute>

The execute flag alters the behaviour of the script by executing migrates 
instead of printing them to the command line interface.  These migrates are 
created instantly and will silently run in the background until they complete. 
Once a migrate has been started it cannot be halted.

=item B<-f, -force>

This flag will suppress the exit condition that is triggered if no complete
solution is possible.  This means the script will continue to run, executing
or printing out migrates that will result in improvements to the extent
balance, but not a total solution.

=item B<-r, -recursive>

When placed in recursive mode the script will make multiple passes of a logical
model of the MDiskGrp to find a complete balancing solution.  The commands will
be printed out in "phases" - sets of commands that can be safely run
concurrently.  In this mode the restriction of the number of migrates will be
ignored.

When set to execute mode the script will execute migrates, wait until they 
complete and then execute more migrates until the extents in the MDiskGrp have 
been optimally balanced instead of making only a single pass.  This operation 
is safe and can be ended at any time and then resumed by simply re-running the 
script.

Optionally specify a delay between checks.  Only applicable to execution 
recursive mode.

=item B<-c, --cluster hostname>

Specify the hostname of the cluster to connect to.  Either the IP of the cluster
or the hostname of the cluster must be specified.

=item B<-i, --ip address>

Specify the IP address of the cluster to connect to.  Either the IP of the 
cluster or the hostname of the cluster must be specified.

=item B<-k, --keyfile file>

Specify the location of the SSH keyfile to use when attempting to connect to the 
cluster.

=item B<-u, --username name>

Specify the username to attempt to connect as on the cluster.  Defaults to 
"admin".

=item B<-s, --ssh application>

Specify the SSH application that should be used to connect to the SVC cluster.
For more details on valid applications, please refer to the documentation for
IBM::SVC.

=item B<-v, --verbose>

Produces output on the progress of the operation of the script.  The default
behaviour is to run silently, only producing the final output or error 
messages.

=item B<-z, --zRetryDelay>

Specify the delay in seconds between retries in case of SVC cluster connection failures. 
Defaults to 5 secs.


=item B<-h, --help>

Prints a usage statement and exits without performing any actions.

=back

The default behaviour of the script is to print out a single set of migrate 
commands that can be run concurrently.  Executing these commands will rearrange 
extents in a manner that is constructive towards having a completely balanced 
MDiskGrp.  The script will consider all striped VDisks and all non-image MDisks 
in the MDiskGrp.

=head1 EXAMPLE

balance.pl mdiskgrp0 -c svc100045 -v -t 0,1,2,3 -n 24

=head1 LIMITATIONS

This script will automatically scan for non-optimal state MDisks and
VDisks.  Detection will prompt a script abort unless this has been
overridden with the --force all|unstable flag.  It is highly recommended that you
do NOT run this script against an MDiskGrp that fails this health check.

Both image mode and sequential mode disks are automatically ignored by the 
script.  This cannot be overridden.  To balance a sequential disk, first convert
it to a striped disk.

This script will not function correctly with fewer free extents than the number
of MDisks involved in the operation.  The script will automatically halt
execution if this condition is met.  This block can be overridden using the
--force [all|partial] flag at the command line upon invocation.

=head1 EXIT STATUS

The following are possible exit status values that can occur from running this 
script.  For information explaining error messages regarding connection or SVC 
activities, please consult the perldoc for IBM::SVC and the documentation for 
the SVC command line interface.

=over 4

=item 0

Successful operation - the script has executed as specified and produced the 
required results.

=item 1

Invalid parameter - one or more of the command line parameters is erroneous and
needs to be corrected.

=item 2

Invalid MDiskGrp or unable to connect to the cluster - an error occured whilst 
trying to connect to the cluster and verify the MDiskGrp.

=item 3

Connection error - an error occurred whilst attempting to collect further 
information from the SVC cluster.

=item 4

Partial solution - the script is only able to partially balance the target 
extents.  Check there is sufficient space available to perform the operation.

=item 5

No solution - the script is unable to make any further progress. Check there is
sufficient space available to perform the operation.

=item 6

Unexpected SVC State - unusual feedback from the SVC cluster resulted in the
failure of the script.

=item 10

Health Check failure - the script has detected a VDisk or MDisk that is in a
non-optimal state.

=back

=head1 COPYRIGHT

=head1 SEE ALSO

L<IBM::SVC Perldoc>, L<SVC Command Line Interface Manual>

=cut

#
#  ----------------------------------------------------------------------------
#
# Summary of Exit Status Numbers:
#
# 0. Success.
# 1. Invalid parameter.
# 2. Invalid MDiskGrp or error establishing a connection to the SVC.
# 3. Connection error occured during data collection.
# 4. Script can only accomplish a partial solution.
# 5. Script cannot make any further progress.
# 6. Unexpected SVC cluster condition. 
# 10. Health Check failure.
#
#  ----------------------------------------------------------------------------
#


use IBM::SVC;

use strict;
use Getopt::Long;
use POSIX qw(floor);

#
# Functions Marker
#
#  ----------------------------------------------------------------------------
#
# This section contains the following utility functions:
#
# All major functionality has been left within the body of the main script
# for the purpose of clarity. The functions listed here perform minor tasks
# with simple functionality that can be abstracted without reducing the
# clarity of the code.
#
# sub usage ($message)
# 	Prints the error message supplied and a short usage statement before
# 	aborting the script, exit status 1.
#
# sub help ()
# 	Prints a long usage statement and aborts the script, exit status 0.
#
# sub error ($message)
#	Prints the error message to STDERR.
# 	A time/date/scriptname header is applied to messages.
#
# sub message ($message, $stamp, $handle)
#	Prints the message to $handle.  Prints a time/date/script name stamp
#	if $stamp is true.  $handle must be a reference to a filehandle.
#
# sub timestamp
# 	Returns a formatted string containing time, date information and the
# 	name of the script.
#
# sub fatal ($error, $status)
# 	Prints the error message and aborts the script with the given exit
# 	status.
# 
#  ----------------------------------------------------------------------------
#

# Function "usage"
#
# This function takes a short error message as a parameter, appends a short
# script usage statement, prints it and aborts the script with exit status 1.
#
# For more information see the function "fatal".
#
sub usage {
	my $error = shift;
	my $script = ($0 or "balance.pl");
	
	fatal (
		"$error\n".
		"$script Usage:\n".
		"\t$script MDiskGrp [-t VDisk,VDisk,...] [-m MDisk,MDisk,...]\n".
		"\t\t[-n number] [-e] [-f] [-r [delay]] -c cluster | -i ip\n".
		"\t\t[-k keyfile] [-u username] [-s application] [-v] [-z [retry delay]] [-h]\n".
		"Invoke '$script --help' for long usage statement.", 1
	);
}

# Function "help": Prints a long usage method.
#
# This function prints a long usage statement and aborts the script with exit
# status 0.  Supplying -h at the command line results in this function being
# invoked.
#
sub help {

my $script = ($0 or "balance.pl");
message (
"$script Usage:\n".
"\t$script MDiskGrp [-t VDisk,VDisk,...] [-m MDisk,MDisk,...]\n".
"\t\t[-n number] [-e] [-f] [-r [delay]] -c cluster | -i ip\n".
"\t\t[-k keyfile] [-u username] [-s application] [-v] [-h]\n".
"\n".
"$script MDiskGrp\n".
"\t[-t|--target VDisk01,Vdisk02,...]\n".
"\t[-m|--media MDisk01,MDisk02,...]\n".
"\t[-n|--number migrate_limit]\n".
"\t[-e|--execute]\n".
"\t[-f|--force]\n".
"\t[-r|--recursive [delay]]\n".
"\t[-c|--cluster hostname | -i|--ip address]\n".
"\t[-k|--key file]\n".
"\t[-s|--ssh application]\n".
"\t[-u|--username name]\n".
"\t[-v|--verbose]\n".
"\t[-z|--zRetryDelay [retry delay]]\n".
"\t[-h|--help]\n".
"\n".
"Invoke this script with the name of the MDiskGrp you wish to\n".
"rebalance.  Additional options can be specified to alter behaviour:\n".
"\n".
"-t, --target      Specify which VDisks to balance.  Default behaviour is to\n".
"                  balance all VDisks in the MDiskGrp.\n".
"\n".
"-m, --media       Specify which MDisks extents can be moved to and\n".
"                  from.  Default behaviour is to use all MDisks.\n".
"\n".
"-n, --number      Constrain the total number of migrates.  If the total\n".
"                  number of migrates running on the SVC is equal to or\n".
"                  greater than this figure, the script will not spawn\n".
"                  any more migrates.  Only applicable when used with -e.\n".
"\n".
"-e, --execute     If this flag is set the script will execute the migrate\n".
"                  commands instead of just printing them to screen.\n".
"\n".
"-f, --force       The script will attempt to improve the distribution of\n".
"                  extents even if there is no possible optimal solution.\n".
"\n".
"-r, --recursive   Repeated passes are made by the script until an optimal\n".
"                  solution is reached.  The script will wait for migrates\n".
"                  to finish and then run more.  Optionally specify the.\n".
"                  delay between checks, applicable with -e.\n".
"\n".
"-c, --cluster     Specify the hostname of the cluster to connect to.\n".
"\n".
"-i, --ip          Specify the IP address of the cluster to connect to.\n".
"                  If -c is also specified both values are sent to IBM::SVC.\n".
"\n".
"-k, --key         Specify the key file for use in making SSH connections.\n".
"\n".
"-s, --ssh         Specify the application used for making SSH connections.\n".
"\n".
"-u, --username    Specify the username for use in making SSH connections.\n".
"\n".
"-v, --verbose     If this flag is set the script will provide more detail\n".
"                  and depth in the output.\n".
"\n".
"-z, --zRetryDelay Specify the delay in seconds between retries in case of\n".
"                  SVC cluster connection failures.\n".
"\n".
"-h, --help        Prints this usage statement.\n".
"\n".
"For more information, please consult the perldoc for this script.\n"
, 0);

exit 0;

}

# Function "error": Write a message to STDERR.
#
# Example: error ("My error message");
#
# The first parameter defines the error message to be output to the user.  The
# function automatically dictates to the function message that the log tag
# must be printed and that the error must be reported to STDERR.
#
sub error {
	message (shift, \*STDERR);
}

# Function "message": Write a message to a file handle.
#
# Example: message ("My Message", "STDOUT")
#
# The first parameter defines the string message to be output to the user.
# The second parameter is the file handle to print to.
# 
sub message {
	my $message = shift;
	my $stamp = shift;
	my $handle = shift;
	
	unless ($handle) { $handle = \*STDOUT; }
	unless ($message) { return; }
	chomp $message;
	
	print $handle "$message\n";
}

# Function "timestamp": Return the current time in the format HH:MM:SS MM:DD:YY.
#
# Accepts no parameters.  Output is in the form of time date.
# e.g. 6:24:12 3/01/05
# 
sub timestamp {
	# Get the local time information.
	# Discard the last 3 values as we don't need them.
	# 
	my ($sec, $min, $hour, $mday, $mon, $year, undef) =
		localtime(time);
	# need to add 1 to month since array starts with 0
    $mon = $mon + 1;
	my $script = ($0 or "balance.pl");
	my $handle = shift;
	
	$year %= 100;
	unless ($handle) { $handle = \*STDOUT; }
		
	message sprintf "\n[\%2.2d:\%2.2d:\%2.2d \%2.2d/\%2.2d/\%2.2d] [\%s]\n", 
		$hour, $min, $sec, $mon, $mday, $year, $script;
}

# Function "fatal": Print an error message and terminate the script.  
# Accepts two arguements, the error message and the exit status.
#
sub fatal {
	# Delegate the printing.
	error shift;
	exit shift;
}

#
# Main Script Marker 
# 
#  ----------------------------------------------------------------------------
#
# The main script follows this basic process flow:
#
# 1. Parse the command line parameters.
# 	<- Exit: Invalid parameters.
# 	<- Exit: Usage Statement.
# 2. Attempt to connect to SVC cluster.
# 	<- Exit: Unable to connect.
# 3. Query the cluster for information on the MDiskGrp etc.
# 	<- Exit: Invalid Parameters
#   <- Exit: Failed Health Check
# 	<- Exit: SVC Error
# 4. Query the cluster for information on the distribution of extents.
# 5. Construct a model of the MDiskGrp and calculate possible solutions.
# 	<- Exit: Insufficient free space.
# 	<- Exit: No optimal solution.
# 	<- Exit: No solution.
# 6. Create a list of commands to create migrates that can be run concurrently.
# 7. Print the list of commands [alt: execute list of commands].
# 8. End [alt: wait for migrates to complete, repeat].
#
# If the script is recursive then the state variables such as the knowledge of
# the cluster is erased each time an iteration completes.  This information
# must then be rediscovered.  This prevents user run migrates from creating 
# complications with the script (although they may still hinder it or create a
# situation in which no [optimal] solution exists).
#
# More information on IBM::SVC can be found in the perldoc for SVC.pm.
#
# Three main data structures are created and used in this script:
#
#  1. $mdisk_ref:  Reference to a hash of references to hashes.  Indexed by
#                  MDisk IDs, storing the name, total extents and free extents.
#  2. $vdisk_ref:  Reference to a hash of references to hashes.  Indexed by
#                  VDisk IDs, storing the name and total extents.
#  3. $extent_ref: Reference to a hash of references to hashes of references to
#                  hashes... indexed by MDisk ID, VDisk ID, storing the number
#                  of extents, optimal extents and a migration flag that is 
#                  true if the extents are locked by a migrate.
#
# This script is split into a series of code blocks for the purposes of scope
# restriction and clarity of code.  The functional purposes of these blocks
# of code are as follows:
#
# Preamble: Check parameters, connection to SVC, start recursive block.
#
#  1. Creation of the $mdisk_ref data structure.
#  2. Creation of the $vdisk_ref data structure.
#  3. Creation of the $extent_ref data structure, calculate total extents and
#     migration locks.
#  4. Calculate optimal extents.
#  5. Feasibility validation check.
#  6. Calculation of the migrate operations required, output.
#
# Finally: End recursive block.
#  
#  ----------------------------------------------------------------------------
#

# These variables are globally scoped and associated with values gathered from
# the command line parameters passed to this script.  They are persistent
# throughout multiple recursions of this script.  The script relies on the user
# passing the same parameters for multiple invocations.
# 
my ($csVDisk, $csMDisk, $numberMigr, $flagExecute, $flagForce, $flagRecursive,
	$hostname, $ipaddr, $keyfile, $username, $flagVerbose, $flagHelp, 
	$flagDebug, $sshMedium, $recursionDelay, $zRetryDelay);

# This is used to determine the size of the volume set aside for quorum on a
# quorum disk.  If the extent size is less than 256mb, then the quorum disk 
# size is 256mb.  Otherwise, it is equal to the extent size.
# 
our $extentSize;

# The behaviour of the script changes after the first run, both in terms of
# functionality and the type of messages that are delivered.
# 
my $flagFirstRun = 1;

# Use Getopts::Long to parse the command line parameters.  For more information
# on the usage of Getopts, please refer to the relevant perl documentation.
# The purpose of these parameters are detailed in the help and perldoc sections.
#
GetOptions (
	"target=s"   => \$csVDisk,       "media=s"     => \$csMDisk,
	"number=i"   => \$numberMigr,    "execute"     => \$flagExecute,
	"force:s"    => \$flagForce,     "recursive:i" => \$flagRecursive,
	"cluster=s"  => \$hostname,      "ip=s"        => \$ipaddr,
	"key=s"      => \$keyfile,       "username=s"  => \$username,
	"verbose"    => \$flagVerbose,   "help"        => \$flagHelp,
	"debug"      => \$flagDebug,     "ssh=s"       => \$sshMedium,
	"zRetryDelay:i" => \$zRetryDelay );


# Check for the presence of the help flag.  If specified, print the long
# usage statement and end the script.
# 
if ($flagHelp) { help (); }

# Assume any remaining strings to be the specified MDiskGrp.
# Read it out from @ARGV and check that it is non-empty.
#
my $mdiskgrp = $ARGV[0]; 

unless ($mdiskgrp || $mdiskgrp eq "0") {
		usage ("MDiskGrp not specified.");
}

# Check that the number of migrates field is valid.  Exit if not a true
# natural number.  If an increased output mode has been enabled then a warning
# is printed telling the user that the number of migrates has been limited to
# 32.
#
# NB: 32 is the maximum number of migrates that can run concurrently against
# an SVC cluster.
#
unless ($numberMigr eq "") {
	if ($numberMigr > 0) {
		if ($numberMigr > 32) {
			if ($flagVerbose || $flagDebug) { message (
				"WARNING: Number of migrations specified greater than 32.\n".
				"Value has been defaulted to 32."
			); } 
			$numberMigr = 32;
		}
	}

	else {
		fatal ("Invalid value specified for -n: $numberMigr\n".
			   "Please ensure a natural number is specified e.g. 16", 1);
	}
}

# This code works with the parameter given through the force flag.  The force
# flag specifies how "unsafe" operations should be handled.
#
# Accepted inputs are undef, "all", "partial", "unstable".  Presence only 
# will be replaced with "partial".
#
# * All: Script acts as if both "partial" and "unstable" have been specified.
# * Partial: Forces the script to run when only a partial solution is possible.
# * Unstable: Forces the script to run even when the healthcheck has failed.
#
if (defined $flagForce && $flagForce ne "all" && $flagForce ne "partial" 
			&& $flagForce ne "unstable") {
	
	# If --force is specified without a parameter, it is assumed that
	# "partial" is the intended mode.	
	# 
	if ($flagForce eq "") {
		$flagForce = "partial";
	}
	
	# The supplied parameter is not recognized print an error message
	# and the usage statement.
	# 
	else {
		usage ("Unrecognized parameter for -f (--force).");
	}
}

# Check the value supplied for --recursive.  Possible values:
#
# - Null: Not specified.
# - 0:    Specified, no arguement.
# - "N":  Specified as "N" seconds.
#
if (defined $flagRecursive) {

	# No arguement, use a default value.
	# 
	if ($flagRecursive eq "") {
		$recursionDelay = 30;
		$flagRecursive = 1;
	}

	# Arguement given, use that value.
	# 
	else {
		$recursionDelay = $flagRecursive;
		$flagRecursive = 1;
	}
}

# Check the value supplied for --zRetryDelay.
# No arguement, use a default value.
# 
if ($zRetryDelay eq "") {
	$zRetryDelay = 5;
}





# Attempt to establish a connection to the SVC cluster.  The IBM::SVC module
# is used for this purpose.  Either the hostname or IP address of the cluster
# is required to create a connection.  Default values can be used for other
# fields.
# 
unless ($hostname || $ipaddr) {
	usage ("Please specify cluster hostname or IP address.");
}

# The parameters that have been collected are output to the command line so
# the user can check that the parameters entered are correct and, to a lesser
# extent, to make sure the script is interpreting them correctly.
# 
if ($flagVerbose || $flagDebug) {
	my $message = "Starting Extent Balance script.\n"."Parameters:\n";
	$message .= "\t      MDiskGrp:  $mdiskgrp\n";
	$message .= "\t      --target:  $csVDisk\n"    if $csVDisk || $csVDisk eq "0";
	$message .= "\t       --media:  $csMDisk\n"    if $csMDisk || $csMDisk eq "0";
	$message .= "\t      --number:  $numberMigr\n" if $numberMigr 
												 || $numberMigr eq "0";
	$message .= "\t     --execute:  enabled\n"     if $flagExecute;
	$message .= "\t       --force:  $flagForce\n"  if $flagForce;
	$message .= "\t   --recursive:  $recursionDelay\n" if $flagRecursive;
	$message .= "\t     --cluster:  $hostname\n"   if $hostname;
	$message .= "\t          --ip:  $ipaddr\n"     if $ipaddr;
	$message .= "\t         --key:  $keyfile\n"    if $keyfile;
	$message .= "\t    --username:  $username\n"   if $username;
	$message .= "\t         --ssh:  $sshMedium\n"  if $sshMedium;
	$message .= "\t     --verbose:  enabled\n"     if $flagVerbose;
	$message .= "\t       --debug:  enabled\n"     if $flagDebug;
	$message .= "\t --zRetryDelay:  $zRetryDelay\n" if $zRetryDelay;

	$message .= "\nWARNING! Running the script with -f (--force) set to ".
				"UNSTABLE may well lead \nto UNPREDICTABLE and DETRIMENTAL ".
				"results if the migrations are executed." 
				if ($flagForce eq "all" || $flagForce eq "unstable");
	
	message ($message);
}

# If the script is going to run the commands, give the user a chance to double
# check the parameters that have been specified.
# 
if ($flagExecute && ($flagVerbose || $flagDebug)) {
	message ("Sleeping for 10 seconds, check parameters.  ".
			 "CTRL-C to abort script.");
	sleep 10;
}

# Construct a hash of parameters to send to the IBM::SVC library. It has already
# been determined that either cluster_ip or cluster_name exist.  If both exist, 
# the library decides which to use.  Other values are automatically defaulted by
# the library if not present.
#
# More information can be found in the library's POD.
# 
my $params = {};

$params->{'cluster_ip'} = $ipaddr if $ipaddr;
$params->{'cluster_name'} = $hostname if $hostname;
$params->{'user'} = $username if $username;
$params->{'keyfile'} = $keyfile if $keyfile;
$params->{'ssh_method'} = $sshMedium if $sshMedium;
$params->{'debug'} = $flagDebug if $flagDebug;
$params->{'zRetryDelay'} = $zRetryDelay if $zRetryDelay;


# Create the connection with the parameters set above.
# 
my $svc = IBM::SVC->new($params); 

if ($flagDebug) { timestamp(); message ("Created IBM::SVC instance."); }

# Attempt to connect to the SVC cluster and execute the command "svcinfo
# lsmdiskgrp".  The returned information is used to make sure that:
#
#	* The cluster can be connected to.
#	* The MDiskGrp exists.
#	* We are using the MDiskGrp ID.
# 
# If no error occurs, $info_ref will point at a hash of information on the 
# MDiskGrp specified.  Otherwise, if an error occurred $rc will be non-zero.  
# $info_ref is returned as an error message.
# 
{
	if ($flagDebug) {timestamp();}
	my ($rc, $info_ref) = $svc->svcinfo("lsmdiskgrp", {}, $mdiskgrp);

	
	# Non-zero $rc indicates a problem with the connection or a problem running
	# the command on the SVC cluster.  As the script isn't really concerned with
	# the exact nature of the error, it is just thrown back to the user.
	#
	# In cases where no error message is provided, a default error message is 
	# used.
	#  
	fatal ($info_ref or "Unable to connect to SVC cluster.", 2) if $rc;

	# Assign the value of the MDiskGrp's ID to the MDiskGrp variable - ensures 
	# that this is the correct format for using it as a masking value later.
	#
	$mdiskgrp = $info_ref->{'id'};
	$extentSize = $info_ref->{'extent_size'};

	if ($flagDebug || $flagVerbose) { 
		message ("Connected to SVC Cluster.  MDiskGrp ID: $mdiskgrp.");
	}
}

# RECURSIVE BLOCK STARTS
#  ----------------------------------------------------------------------------
#  
# Define a list that will contain information on migrations that are impeding 
# the progress of the script. This can include migrations spawned by the script 
# and migrations spawned by a third party.
# 
our $waiting_ref = [];

# This is the recursive loop for execution.  The loop is broken by using the
# control structure 'last' or by invoking the 'exit' function.  The main
# script's indentation is not kept consistent with this loop to prevent over
# indentation.
# 
OUTER: while (1) {

	unless ($flagRecursive || $flagFirstRun) {
		error ("Unexpected condition: Not recursive and not first run.",
			"\nThis code was never supposed to be executed, so there's
			a bug somewhere in here.");
		exit 0;
	}

	# On subsequent runs after the first pass, a delay is introduced to allow
	# the migrates to make progress and prevent the amount of times the script
	# is required to connect to the SVC cluster.
	#
	unless ($flagFirstRun) { 

		# Print out the current list of migrates and their progress.  For a
		# more frequent update, it is suggested that the end user run a
		# seperate script using the IBM::SVC library to query to cluster or
		# run the following on the SVC cluster CLI itself:
		#
		#  watch 'svcinfo lsmigrate | grep progress'
		#  
		if ($flagVerbose || $flagDebug) { 
			timestamp ();	
			message (
				"Waiting $recursionDelay seconds for migrate".
				($recursionDelay == 1 ? "" : "s").
				" to complete."
			); 

			foreach my $waiting_migr (@$waiting_ref) {
				message ("-->| $waiting_migr->{'migrate_type'},". 
						" $waiting_migr->{'progress'}%");
			}
		}
		
		# Replace this delay with a value more suited to the scale of the
		# operation where necessary i.e. larger for high free space / extents /
		# mdisks, smaller for tiny extents / little free space.
		# 
		# NOTE: Supply a command line parameter to do this?
		# 
		sleep $recursionDelay; 
	}

	{
		# Get the current migration info from the SVC cluster.
		#
		if ($flagDebug) {timestamp();}
		my ($rc, $migr_ref) = $svc->svcinfo("lsmigrate");


		if ($rc) { fatal ($migr_ref); }
		
		# Check if there are any migrates in the $waiting_ref list.  If there 
		# are, compare this list with the list of ongoing migrates from the SVC.
		# 
		# If any of the migrates in $waiting_ref are no longer present, assume 
		# they have successfully terminated and attempt to make another pass of 
		# the script.
		#
		if (scalar @$waiting_ref > 0) { 
			my $waiting = 1;

			foreach my $waiting_migr (@$waiting_ref) {
				my $present = 0;
				
				MIGR: foreach my $migr (@$migr_ref) {
					
					# Filter any migrates that are not of the same type as the
					# migrate being checked for.
					# 
					unless (
							$waiting_migr->{'migrate_type'}	eq 
							$migr->{'migrate_type'}
					) { 
							next; 
					}

					# Check if the migrate held in $waiting_migr is equal to the
					# current migrate $migr.  This is determined by comparing
					# specified fields that remain constant.  These fields are
					# defined by the type of migration.
					# 
					if (
						
						# For an extent migration, compare the VDisk, source
						# MDisk, target MDisk and number of extents.
						# 
					   ($waiting_migr->{'migrate_type'} 
							eq "MDisk_Extents_Migration"
					    && $waiting_migr->{'migrate_vdisk_index'} 
							eq $migr->{'migrate_vdisk_index'}
					    && $waiting_migr->{'migrate_source_mdisk_index'} 
							eq $migr->{'migrate_source_mdisk_index'}
					    && $waiting_migr->{'migrate_target_mdisk_index'} 
							eq $migr->{'migrate_target_mdisk_index'}
					    && $waiting_migr->{'number_extents'} 
							eq $migr->{'number_extents'}
			   			)

						# For an MDisk migration, compare the MDisk and 
						# MDiskgrp.
						# 
					|| ($waiting_migr->{'migrate_type'} 
							eq "MDisk_Migration"
					    && $waiting_migr->{'migrate_mdisk_index'} 
							eq $migr->{'migrate_mdisk_index'}
						&& $waiting_migr->{'mdisk_grp_id'} 
							eq $migr->{'mdisk_grp_id'}
						) 

						# For an MDiskGrp Migration, check the VDisk and
						# MDiskgrp.
						# 
					|| ($waiting_migr->{'migrate_type'} 
							eq "MDisk_Group_Migration"
						&& $waiting_migr->{'migrate_vdisk_index'} 
							eq $migr->{'migrate_vdisk_index'}
						&& $waiting_migr->{'mdisk_grp_id'} 
							eq $migr->{'mdisk_grp_id'}
						) 

						# For an Image Migration check the VDisk, target MDisk
						# and target MDiskGrp.
						# 
					|| ($waiting_migr->{'migrate_type'} 
							eq "Migrate_to_Image"
						&& $waiting_migr->{'migrate_vdisk_index'} 
							eq $migr->{'migrate_vdisk_index'}
						&& $waiting_migr->{'migrate_target_mdisk_index'} 
							eq $migr->{'migrate_target_mdisk_index'}
						&& $waiting_migr->{'migrate_target_mdisk_group'} 
							eq $migr->{'migrate_target_mdisk_group'}
						)) {
					
						# Update the migrate's progress.
						#
						$waiting_migr->{'progress'} = $migr->{'progress'};
						
						# If the above condition is matched, the migrate is
						# still present.  Fall out of the loop.
						# 
						$present = 1;
						last MIGR;
					}
				}
				
				$waiting = 0 unless $present;
			}
		
			# Still waiting, so return to the start.
			# 	
			if ($waiting) {
				$flagFirstRun = 0;
				next OUTER;
			}
		}
		
		# Count the number of migrates.  If it is greater than or equal to the 
		# limit on the number of migrates this pass of the script is aborted.
		#
		if (scalar @$migr_ref > ($numberMigr or 32)) {
			$flagFirstRun = 0;
			next OUTER;
		}
	}
#
#  ----------------------------------------------------------------------------
# RECURSIVE BLOCK ENDS

# MDiskGrp Health Check
#
# This will cause the script to abort if any of the MDisks or VDisks in the
# MDisk group are in a non-nominal state.  Specifying the -f flag at the
# command line with "all" or "unstable" will override this.
#
{
	my $warning = "";
		
	# Get the required information from the SVC cluster.
	# 
	if ($flagDebug) {timestamp();}
	my ($rc, $mdisk_info) = $svc->svcinfo("lsmdisk", 
			{'filtervalue' => "mdisk_grp_id=$mdiskgrp"});
	fatal ($mdisk_info or "Unable to connect to SVC cluster.", 3) if $rc;

	if ($flagDebug) {timestamp();}
	my ($rc, $vdisk_info) = $svc->svcinfo("lsvdisk",
			{'filtervalue' => "mdisk_grp_id=$mdiskgrp"});
	fatal ($vdisk_info or "Unable to connect to SVC cluster.", 3) if $rc;

	# Check the field "status" for each MDisk.  If the value for this field is
	# not "online" then the healthcheck flags this disk.
	#
	foreach my $mdisk (@$mdisk_info) {
		unless ($csMDisk =~ /^(.*[,:]|)$mdisk->{'name'}([,:].*|)$/ 
				|| $csMDisk =~ /^(.*[,:]|)$mdisk->{'id'}([,:].*|)$/ ) {
			
			if ($mdisk->{'status'} ne "online") {
				$warning .= ">| MDisk $mdisk->{'name'} [$mdisk->{'id'}] ".
					"has state $mdisk->{'status'}.\n";
			}
		}
	}

	# Check the field "status" for each MDisk.  If the value for this field is
	# not "online" then the healthcheck flags this disk.
	#
	foreach my $vdisk (@$vdisk_info) {
		unless ($csVDisk =~ /^(.*[,:]|)$vdisk->{'name'}([,:].*|)$/ 
				|| $csVDisk =~ /^(.*[,:]|)$vdisk->{'id'}([,:].*|)$/ ) {
			
			if ($vdisk->{'status'} ne "online") {
				$warning .= ">| VDisk $vdisk->{'name'} [$vdisk->{'id'}] ".
					"has state $vdisk->{'status'}.\n";
			}
		}
	}

	# The healthcheck has found some problems.  Print out a warning message
	# and terminate the application unless this has been overridden using the
	# --force flag.
	# 
	if ($warning) {
		timestamp();
		
		if ($flagForce eq "all" || $flagForce eq "unstable") {
			message (
				"WARNING: MDiskGrp Healthcheck FAILED but overridden".
				" by --force.\n$warning"
			);
		}

		else {
			fatal ("MDiskGrp Health Check FAILED.  Reasons:\n$warning", 10);
		}
	}
}

# The following data structures are created from information gathered from the
# SVC.  Information on their form and structure can be found above the code that
# creates them.
# 
our ($mdisk_ref, $vdisk_ref, $extent_ref);

# Populates the MDisk data structure.  The data returned by the SVC call is of
# the form of a list of hashes, of which the following data is required:
#
# 	* MDisk Name
# 	* MDisk ID
#
# Seperate calls are made for each MDisk to retrieve the number of free extents 
# and it's capacity in bytes.  The data structure generated is a hash of hashes 
# indexed by MDisk ID.
# 
# $mdisk_ref->{$mdisk_id} = { 'name' => $name,
#                             'capacity' => $capacity,
#                             'free extents' => $free,
#                             'alt extents' => $alt }
#
# The field alt extents is provided for the purpose of resetting the free 
# extents field when the script is set to recursive in a non execute mode.
# 
{
	if ($flagDebug) { 
			timestamp(); 
			message ("Creating \$mdisk_ref data structure."); 
	}
	
	elsif ($flagVerbose) { 
			timestamp ();
			message ("Collecting MDisk data."); 
	}
 
	# Predefine the ref to be an empty hash for the purpose of clarity.
	# 
	$mdisk_ref = {};
	
	# Run the query command on the SVC cluster, specifying that only MDisks
	# belonging to the specified MDiskGrp are required.
	# 
	if ($flagDebug) {timestamp();}	
	my ($rc, $mdisk_info) = $svc->svcinfo("lsmdisk", 
		{'filtervalue' => "mdisk_grp_id=$mdiskgrp"});
	fatal ($mdisk_info or "Unable to connect to SVC cluster.", 3) if $rc;
	
	# Iterate through the array of MDisks. Check the MDisk are in the desired 
	# operational domain. Once this has been verified, add the MDisk's ID, name
	# and free extents to the data structure.  A call to the SVC is required for
	# each MDisk to gather the free extents info.
	# 
	my $record;
	foreach $record (@$mdisk_info) {
		
		# Retrieves the number of extents that are available for migration in 
		# this MDisk.
		# 
		if ($flagDebug) {timestamp();}
		my ($rc, $extent_info) = $svc->svcinfo("lsfreeextents",	
				{}, $record->{'id'});
		fatal ($extent_info or "Unable to connect to SVC cluster.", 3) if $rc;

		# Retrieves the total capacity of the MDisk, in bytes for precision.
		# (There is not yet a certain way of calculating total extents.)
		# 
		if ($flagDebug) {timestamp();}
		my ($rc, $cap_info) = $svc->svcinfo("lsmdisk", 
				{"bytes"=>undef}, $record->{'id'});
		fatal ($cap_info or "Unable to connect to SVC cluster.", 3) if $rc;

		# If a list of MDisks has been specified, make sure that this MDisk is 
		# present in it.  If this condition is satisfied or no list has been 
		# specified, add the MDisk to the data structure.
		# 
		if ( ($csMDisk ne "" && 
				($csMDisk =~ /^(.*[,:]|)$record->{'name'}([,:].*|)$/ 
				|| $csMDisk =~ /^(.*[,:]|)$record->{'id'}([,:].*|)$/ )
			) || $csMDisk eq "" ) {
			
			# Ensure the disk is in a managed state.  Should not use
			# unmanaged or image mode MDisks.
			# 
			#message ( "MDisk: ID ".$record->{'id'}.", ".$record->{'name'}.", Mode ".$record->{'mode'}."." )
			if (($record->{'mode'} eq 'unmanaged') || ($record->{'mode'} eq 'image')) { 
				message (
					">| Did NOT add MDisk: ID ".$record->{'id'}.", ".
						$record->{'name'}.
					", Mode ".$record->{'mode'}."."
				) if $flagDebug;	
				next; 
			}
			
			#Skip SSD MDisks as they are managed by EasyTier
			#message ( "MDisk: ID ".$record->{'id'}.", ".$record->{'name'}.", Mode ".$record->{'mode'}.", tier=".$record->{'tier'} );
			if ( $record->{'tier'} eq 'generic_ssd' ) { 
				message (
					">| Skipped SSD MDisk: ID ".$record->{'id'}.", ".
						$record->{'name'}.
					", Tier ".$record->{'tier'}."."
				) if $flagDebug;	
				next;
			}
			
			my $capacity = $cap_info->{'capacity'};

			# If the disk is a quorum disk, reduce the total capacity by the
			# size consumed by the quorum data to reflect this.
			# 
			if ($cap_info->{'quorum_index'} ne "") {
				if ($flagDebug) { message (
					"-->| $record->{'name'} is a quorum disk."
				); }
				$capacity -= ($extentSize == 512 ? 512 : 256)*(2**20);
			}
				
			# Add the MDisk to the data structure.  "Alt Extents" is simply a
			# copy of "Free Extents" that is used to revert the number of 
			# free extents when applying the non-execute recursive model.
			# 
			$mdisk_ref->{ $record->{'id'} } = {
				'name'         => $record->{'name'},
				'capacity'     => $capacity,
				'free extents' => $extent_info->{'number_of_extents'},
				'alt extents'  => $extent_info->{'number_of_extents'}
			};
			
			if ($flagDebug) { message (
				">| Added MDisk: ID ".$record->{'id'}.", ".$record->{'name'}.
				", Free Extents ".    $extent_info->{'number_of_extents'}.
				", Capacity ".        $capacity."."
			); }
		}
	}
}

# Populates the VDisk data structure.  The data returned by the SVC call is of
# the form of a list of hashes, of which the following data is required:
#
# 	* VDisk Name
# 	* VDisk ID
#
# This data is then held in a hash of hashes, indexed using VDisk ID. The field
# 'total extents' is calculated by making an additional call for extent data 
# on the VDisk which is summed and set as the total extent value.
#
{
	if ($flagDebug) { 
		timestamp ();
		message ("Creating \$vdisk_ref data structure."); 
	}
	
	elsif ($flagVerbose) { message ("Collecting VDisk data."); }
	
	# Predefine the ref to be an empty hash for the purpose of clarity.
	# 
	$vdisk_ref = {};
	
	# Collects the VDisks that belong to the specified MDiskGrp.  From this data
	# the VDisks ID and Names are used.
	# 
	if ($flagDebug) {timestamp();}


	my ($rc, $vdisk_info) = $svc->svcinfo("lsvdisk", {});

	fatal ($vdisk_info or "Unable to connect to SVC cluster.", 3) if $rc;

	# Check if each VDisk is in our operational domain and then add it to the 
	# data structure.
	# 
	my $record;
	foreach $record (@$vdisk_info) {
		
		# If a list of VDisks has been specified, make sure that this VDisk is
		# present in it.  If this condition is satisfied or no list has been 
		# specified, add the VDisk to the data structure.
		#
		if ( ($csVDisk ne "" &&
				($csVDisk =~ /^(.*[,:]|)$record->{'name'}([,:].*|)$/
				|| $csVDisk =~ /^(.*[,:]|)$record->{'id'}([,:].*|)$/ )
			) || $csVDisk eq "" ) {
		


			if (($record->{'type'} ne "striped") && ($record->{'type'} ne "many")) { next; }

			
			# Check if disks are in the specified mdisk group, or have a mirror which may be 
			#
			if (($record->{'mdisk_grp_id'} ne "$mdiskgrp") && ($record->{'mdisk_grp_id'} ne "many")) { next; }
			my $copyinmdiskgrp=1;
			my $numcopies=0;
			if ($record->{'mdisk_grp_id'} eq "many") { 
				if ($flagDebug) { message (
                                	">| Considering Mirrored VDisk: ID ".$record->{'id'}.".");
				}
				$copyinmdiskgrp=0;
				my ($rc, $copy_info) = $svc->svcinfo("lsvdiskcopy", {}, $record->{'id'});
				fatal ($copy_info or
                                        "Unable to connect to SVC cluster.", 3) if $rc;
				foreach my $copy (@$copy_info) {
					if (($copy->{'mdisk_grp_id'} eq "$mdiskgrp") && ($copy->{'type'} eq "striped")) {
						$copyinmdiskgrp=1;
						$numcopies++;
						if ($flagDebug) { message (
 		                               		">| Copy ID ".$copy->{'copy_id'}." in mdisk_grp_name: ".$copy->{'mdisk_grp_name'}.".");
						}
					}
				}
			}
			next if (!$copyinmdiskgrp);
				

			if ($flagDebug) {timestamp();}
			my ($rc, $extent_info) = $svc->svcinfo("lsvdiskextent", 
					{}, $record->{'id'});
			fatal ($vdisk_info or 
					"Unable to connect to SVC cluster.", 3) if $rc;
			
			my $total = 0;

			# Calculate the sum total of the extents that make up this VDisk.
			# 
			foreach my $extent (@$extent_info) {
				$total += $extent->{'number_extents'};
			}

			# If there are mirrored vdisks, but only 1 copy is in the mdisk group we're balancing
			# then we only have half of the extents available to use.  Also alter the copy count to
			# 1 as we're not considering the copy on the other mdisk group
			#
			my $copy_count = $record->{'copy_count'};
			if ($numcopies == 1) {
				$total = ($total / 2);
				$copy_count = 1;
			}
			
			# Adding the VDisk to the data structure.
			#
			$vdisk_ref->{$record->{'id'}} = {
				'name'          => $record->{'name'},
				'total extents' => $total,
				'copy_count'	=> $copy_count 
			};

			if ($flagDebug) { message (
				">| Adding VDisk: ID ".$record->{'id'}.", ".$record->{'name'}.
				" with $total extents."
			); }
	    }
	}
}

# Populates the Extent data structure.  Two data calls are made to the SVC, the
# results provide the following information:
# 
# 	* List of currently running migrates.
# 	* List of VDisk extent distribution on each MDisk.
# 
# The extent data structure is a hash of a hash of a hash, navigated using
# MDisk IDs -> VDisk IDs -> 'extents'|'migrate'.
#
# During this operation the 'total extents' fields for $mdisk_ref and $vdisk_ref
# are completed by incrementing the value.
#
{
	if ($flagDebug) {
		timestamp();
		message ("Creating \$extent_ref data structure."); 
	}
	elsif ($flagVerbose) { message ("Collecting Extent data."); }
	
	$extent_ref = {};

	# Create a temporary hash of to store each possible vdisk_id and copy_id so that we can create the
	# markers accurately.  Each of these markers is then set against the vdisk id's of all the mdisks 
	# in the group.  We have to build all this information up first before we do this - hence the need
	# to run lsmdiskextent twice - so that we can populate the markers of an mdisk with no vdisks on 
	# it correctly. 

	my $vdisk_marker = {};

	foreach my $mdisk_id (keys %$mdisk_ref) {
		if ($flagDebug) {timestamp();}
       	 	my ($rc, $extent_info) =
                	$svc->svcinfo("lsmdiskextent", {}, $mdisk_id);
        	if ($rc) { fatal ($extent_info or
                	"Unable to connect to SVC cluster.", 3); }

		foreach my $extent (@$extent_info) {
			unless ($vdisk_marker->{$extent->{'id'}}->{$extent->{'copy_id'}}->{'extents'}) {
				$vdisk_marker->{$extent->{'id'}}->{$extent->{'copy_id'}}->{'extents'} = 0;
			}
		}
	}

	
	# Using the existing data set of MDisks, iterate through each MDisk in the 
	# operational domain.  Run the lsmdiskextent query for each MDisk.
	#
	# When this data has been gathered, add a new entry to the $extent_ref 
	# structure for the MDisk with an entry for each VDisk.
	#
	# At the same time, update the $mdisk_ref and $vdisk_ref data by 
	# incrementing their total extents values by the amounts discovered.
	#
	foreach my $mdisk_id (keys %$mdisk_ref) { 
		if ($flagDebug) {timestamp();}
		my ($rc, $extent_info) = 
			$svc->svcinfo("lsmdiskextent", {}, $mdisk_id);
		if ($rc) { fatal ($extent_info or 
				"Unable to connect to SVC cluster.", 3); }

		if ($flagDebug) { message (
			">| Creating entry for MDisk $mdisk_ref->{$mdisk_id}->{'name'}."
		); }
		
		# Each VDisk is registered  with this MDisk in the $extent_ref data 
		# structure, even if it is empty.  This is crucial for the later 
		# calculation of migrate operations as extents will be moved to these 
		# empty extents groups.
		# 

		foreach my $vdisk_id (keys %$vdisk_ref) {
			for (my $copy_id=0; $copy_id<2; $copy_id++) {
				if (exists $vdisk_marker->{$vdisk_id}->{$copy_id}->{'extents'}) {
					unless (exists $extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'extents'}) {
						$extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'extents'} = 0;
						if ($flagDebug) { message (
		                                       "-->| Added copy $copy_id marker for $vdisk_ref->{$vdisk_id}->{'name'}."
                               			); }
					}
				}
			}
		}

	
               # Check to see if the VDisk has any extents - it will have an entry in
               # this information if it does. If the required information is found,
               # create an entry in the $extent_ref data structure.
               #
               foreach my $extent (@$extent_info) {
                       foreach my $vdisk_id (keys %$vdisk_ref) {
                               if ($extent->{'id'} != $vdisk_id) { next; }
                               $extent_ref->{$mdisk_id}->{$vdisk_id}->{$extent->{'copy_id'}}->{'extents'} =
                                       $extent->{'number_of_extents'};

                               if ($flagDebug) { message (
                                       "-->| Added data for $vdisk_ref->{$vdisk_id}->{'name'}, copy $extent->{'copy_id'}"
                                       .": $extent_ref->{$mdisk_id}->{$vdisk_id}->{$extent->{'copy_id'}}->{'extents'}"
                                       ." extents."
                               ); }
                       }
               }
       	}

	if ($flagDebug) {
		timestamp();
		message ("Checking for locked MDisk/VDisk fragments using lsmigrate.");
	}
	elsif ($flagVerbose) { message ("Checking current migrates."); }
	
	# Get the migrate information.  Iterate through this information and
	# apply any derived results to the data structure i.e. any MDisk/VDisk
	# fragments we now know to be locked will be locked.
	# 
	if ($flagDebug) {timestamp();}
	my ($rc, $migr_info) = $svc->svcinfo("lsmigrate");


	fatal ($migr_info or "Unable to connect to SVC cluster.", 3) if $rc;

	if ($flagDebug) { 
		message ("Checking ".scalar @$migr_info." running migrate".
				(scalar @$migr_info == 1 ? "." : "s.")) if $migr_info; 
	}

	# Iterate through the list of migrates.  There are four different types of 
	# migrates to be considered, all of which need to be handled differently.
	#
	#  - MDisk_Extents_Migration: Moving a set of extents from one MDisk to 
	#                             another.
	#  - MDisk_Migration:         Deletion of an MDisk.
	#  - MDisks_Group_Migration:  Migrate a VDisk from one MDiskGrp to 
	#                             another.
	#  - Migrate_to_Image:        Create an image of the VDisk on an MDisk
	#                             and add it to an MDiskGrp. 
	# 
	foreach my $migrate (@$migr_info) {
		
		my $type = $migrate->{'migrate_type'};
		
		# Returned if command svctask migrateexts is in use. If there exists an
		# MDisk in the data structure that is the subject of the operation, 
		# flag the subject MDisk->VDisk and target MDisk->VDisk.
		# 
		if ($type eq "MDisk_Extents_Migration") {
			unless (exists $mdisk_ref->{
					$migrate->{'migrate_source_mdisk_index'}
				} && exists $vdisk_ref->{
					$migrate->{'migrate_vdisk_index'}
			}) { next; }
				
			if ($flagDebug) { message (
				"Found $type with subject VDisk ".
				"$vdisk_ref->{$migrate->{'migrate_vdisk_index'}}->{'name'}".
				" and MDisk ".$mdisk_ref->
					{$migrate->{'migrate_source_mdisk_index'}}->{'name'}."."
			); }
	
			# Lock the target MDisk->VDisk extents, as it will not be possible 
			# to migrate extents from this source.
			# 
			$extent_ref->{$migrate->{'migrate_source_mdisk_index'}}
				->{$migrate->{'migrate_vdisk_index'}}->{'locked'} = 1;

			$extent_ref->{$migrate->{'migrate_target_mdisk_index'}}
				->{$migrate->{'migrate_vdisk_index'}}->{'locked'} = 1;
		}

		# Returned if command svctask rmmdisk is in use. Although this migrate 
		# may occur, there should not be any instance where we were able to get 
		# details on a disk that had been flagged as deleted.  Handle included 
		# "just in case".
		#
		elsif ($type eq "MDisk_Migration") {
			unless (exists $mdisk_ref->{$migrate->{'migrate_mdisk_index'}}) {
				next;
			}
				
			# This MDisk is being deleted, make sure there are no VDisks present
			# that are in our domain. If there are VDisks present that are in 
			# the operational domain, cancel the operation due to mass 
			# brokenness.
			#	 
			if ($extent_ref->{$migrate->{'migrate_mdisk_index'}}) { 
				fatal ( 
					"Target MDisk ".$mdisk_ref->{
						$migrate->{'migrate_mdisk_index'}
					}->{'name'}." has been flagged for deletion "
					."and has target VDisks present.", 6
				);
			}
			
			if ($flagDebug) { message (
				"Found $type with subject MDisk ".
				"$mdisk_ref->{$migrate->{'migrate_mdisk_index'}}->{'name'}."
			); }
	
			# Otherwise, set the free extents of the MDisk to 0 to make sure 
			# that it does not interfere with the rest of the proceedings.
			#
			$mdisk_ref->{$migrate->{'migrate_mdisk_index'}}->
				{'free extents'} = 0;

			$mdisk_ref->{$migrate->{'migrate_mdisk_index'}}->
				{'alt extents'} = 0;
		}

		# Returned if command svctask migratevdisk is in use. If there exists a
		# VDisk in the data structure that is the subject of this operation, 
		# flag the whole VDisk.
		# 
		elsif ($type eq "MDisk_Group_Migration") {
			unless (exists $vdisk_ref->{
					$migrate->{'migrate_source_vdisk_index'}
			}) { next; }
			
			if ($flagDebug) { message (
				"Found $type with subject VDisk ".
				"$vdisk_ref->{
					$migrate->{'migrate_source_vdisk_index'}
				}->{'name'}."
			); }
			
			# Flag the entire VDisk as being migrated, thus ensuring that no 
			# attempts to move the extents will be made.	
			# 
			foreach my $subject (keys %$extent_ref) {
				$extent_ref->{$subject}->{
						$migrate->{'migrate_source_vdisk_index'}
				}->{'locked'} = 1;
			}
		}

		# Returned if command svctask migrate to image is in use. If the VDisk 
		# involved in this operation is present, lock all associated extents.
		# 
		elsif ($type eq "Migrate_to_Image") {
			unless (exists $vdisk_ref->{$migrate->{'migrate_source_vdisk_index'}}) {
				next;
			}
			
			if ($flagDebug) { message (
				"Found $type with subject VDisk ".
				"$vdisk_ref->{$migrate->{'migrate_source_vdisk_index'}}->{'name'}."
			); }
			
			# Flag the entire VDisk as being migrated, thus ensuring that no 
			# attempts to move the extents will be made.
			# 	
			foreach my $subject (keys %$extent_ref) {
				$extent_ref->{$subject}->{$migrate->{'migrate_source_vdisk_index'}}
					->{'locked'} = 1;
			}
		}
	}
}

# Calculate the optimal extents value for each MDisk/VDisk extent grouping.
# This value is obtained from the following formula:
# 
# 	floor ( (mdisk_capacity * vdisk_ext) / total_capacity )
#
# This algorithim iterates through the entire extents data structure, adding
# an additional key/value pair of 'optimal' and the calculated value.  This
# value is used in the next code block when the script derives a set of
# migrate commands.
#
# Checks the overall state of the MDisks to see whether they are already
# balanced.  This is done by assuming that the extents are balanced and then
# seeking to disprove this assumption by finding a group of extents that
# does not have 'extents' >= 'optimal extents'.
#
{	
	my $total_extents = 0;
	my $total_capacity = 0;
	my $flagBalanced = 1;

	# Calculate the total extents by taking the summation of each MDisk's
	# 'total extents' field.
	# 
	foreach my $mdisk_id (keys %$mdisk_ref) {
		$total_extents += $mdisk_ref->{$mdisk_id}->{'total extents'};
		$total_capacity += $mdisk_ref->{$mdisk_id}->{'capacity'};
	}
	
	if ($flagDebug) { 
		timestamp ();
		message ("Performing optimal extent calculations:\n".
				 "Total number of extents caculated as $total_extents.");
	}
	elsif ($flagVerbose) { 
		timestamp ();
		message ("Caculating optimal extent distribution.");
	}
	
	# For each MDisk/VDisk extent group, caculate the optimal number of
	# extents as described by the formula above.  This value is held in the
	# $extent_ref data structure.
	# 
	foreach my $mdisk_id (keys %$mdisk_ref) {
		
		if ($flagDebug) { message (
			">| Calculating values for ".$mdisk_ref->
				{$mdisk_id}->{'name'}."."
		); }
			
		foreach my $vdisk_id (keys %$vdisk_ref) {
		
			# Calculate the optimal number of extents in this area.
			# 

			my $tot_v_ext = $vdisk_ref->{$vdisk_id}->{'total extents'};
			for (my $copy_id=0; $copy_id<2; $copy_id++) {
				if (exists $extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}) {
					$tot_v_ext=$tot_v_ext/2 if ($vdisk_ref->{$vdisk_id}->{'copy_count'} > 1);
					$extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'optimal'} =
	                                floor (($mdisk_ref->{$mdisk_id}->{'capacity'} * $tot_v_ext) / $total_capacity);
								
					# Check to see if these extents are "balanced".
					#
					if ($extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'extents'} < 
							$extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'optimal'}) {
						$flagBalanced = 0;
					}
	
					if ($flagDebug) { message (
						"-->|".$vdisk_ref->{$vdisk_id}->{'name'}.
						" copy $copy_id: Optimal Extents ".
						$extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'optimal'}.".");
					}
				}
			}
		}
	}


	# This block is executed if the target disks are already balanced.  Print
	# an "error" message to the command list and abort the operation, status 0.
	# 
	if ($flagBalanced) {
		timestamp ();
		
		if (!$flagRecursive || $flagFirstRun) {
			message ("The extents for the target MDiskGrp are already balanced.");
			message ("Aborting...");
		}
		else {
			message ("Extents are balanced, operation completed.");
		}
		
		exit 0;
	}
}

# Examine the free space available to determine whether it is possible to 
# feasibly complete this operation.  There are three possible results from this
# examination:
#
#  * Feasible:   Operation can run to completion without issue if cluster
#                state remains constant.
#  * Partial:    The operation can be run and be semi successful, but a full
#                solution cannot be reached in the current state.
#  * Impossible: No further progress can be made in the current state.
#
# The operation is feasible if neither of the other two conditions hold.
#
# The operation is partially feasible if it is impossible to migrate extents 
# as required to/from one or more of the MDisks.  This can be due to the 
# exclusion of one or more VDisks in the VDisk domain, or due to migrations 
# running on the MDisk.
#
# The operation is impossible if there are no free extents that can be used to
# migrate information, or if no movement is possible due to exclusion by domain
# or ongoing migration.
#
# In the case of a recursive operation with ongoing migrations the script will
# cycle until such a time that these migrations do not hinder progress.
#
{
	my $partial = "";
	my $impossible = 1;
	my $none_free = 1;

	# Iterate through each MDisk for which records exist.  Determine whether
	# the disk is deadlocked.  A disk is deadlocked if:
	#
	#  * Some/all disks are deadlocked resulting in...
	#  * From the remaining disks:
	#        sum (optimal) - sum (extents) > free extents
	#  
	for my $mdisk_id (keys %$mdisk_ref) {
		my $sumOptimal = 0;
		my $sumExtents = 0;
			
		# Calculate the values of sum (optimal) and sum (extents) from extents 
		# that aren't deadlocked.
		#  
		for my $vdisk_id (keys %$vdisk_ref) {
			for (my $copy_id=0; $copy_id<2; $copy_id++) {
				if (exists $extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'optimal'}) {
					unless ($extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'locked'}) {
						$sumOptimal += $extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'optimal'};
						$sumExtents += $extent_ref->{$mdisk_id}->{$vdisk_id}->{$copy_id}->{'extents'};
					}
				}
				
			}
		}

		# Use this information to work out if:
		#   sum (optimal) - sum (extents) > free extents	
		#
		if ($mdisk_ref->{$mdisk_id}->{'free extents'} < 
				($sumOptimal - $sumExtents)) {

			$partial .= "Insufficient space in MDisk $mdisk_id for balancing.";
		}

		else {
			$impossible = 0;
		}

		# If there are no free extents, report as impossible.
		#
		unless ($mdisk_ref->{$mdisk_id}->{'free extents'} == 0) {
			$none_free = 0;
		}
	}
	
	# Check to see if the number of free extents is greater than or equal to
	# the number of MDisks.  To guarantee a complete solution this condition
	# must be met.
	#
	my $freetotal = 0;

	for my $mdisk (keys %$mdisk_ref) {
		$freetotal += $mdisk_ref->{$mdisk}->{'free extents'};
	}

	if ($freetotal < scalar keys %$mdisk_ref) {
		$partial .= "\nFull solution not guaranteed as there are fewer ".
			"free extents than target MDisks.";
	}
	
	# No solution - impossible - end the script with an error message. 
	# Alernatively, go to the next iteration of the script with a list of 
	# migrations that are directly hindering progress.
	# 
	if ($impossible || $none_free) {
			
		# Grab a list of migrates to be waited on.  This list will be compared
		# against a new list, with the script iterating whenever a migrate
		# finishes.
		# 
		if ($flagDebug) {timestamp();}
		my ($rc, $migr_ref) = $svc->svcinfo("lsmigrate");
		if ($rc) { fatal ($migr_ref or "Unable to connect to SVC cluster.", 3);}
		
		unless ($flagRecursive && $flagExecute && (scalar @$migr_ref)) {
			timestamp() if ($flagDebug || $flagVerbose);
			fatal ("No solution possible: Check current migrates, then".
				" ensure there is space available.", 5) 
		}
		
		$waiting_ref = $migr_ref;
		$flagFirstRun = 0;
		next OUTER;
	}
	
	# Partially impossible - ignore if --force has been specified by the user.
	# Otherwise, end the script with an error message.
	# 
	if ($partial && !($flagForce eq "all" || $flagForce eq "partial") 
			&& $flagFirstRun) {
		timestamp() if ($flagDebug || $flagVerbose);
		fatal "No complete solution: Can only partially balance.".
			"\nReason(s): $partial".
			"\nRe-run with \"-f all\" or \"-f partial\" to override.", 4;
	}
}

# Make a single iteration of the MDisks for each pass.  For each VDisk,
# iterate through the remaining MDisks, attempting to push away spare extents
# or pull in required extents.  Will not attempt to push away more than needed
# by the recipient or pull in more than can be supplied.
#
# An outer loop will control the recursive non-execution list of migrations.
#
{
	if ($flagDebug || $flagVerbose) { 
		timestamp ();
		message ("Calculating the migration commands."); 
	}

	my $n = 0;
	my @migrates;
	my $flagPushed;

	# "Inner" loop.  Note: Not indented as this only applies to a single
	# execution use case.
	#  -----------------------
	INNER: while (1) {
	#  -----------------------
	# 
			
	# Keep a counter for recursive migration banding.
	# Reset the pushed flag.
	# 
	$n++;
	$flagPushed = 0;
	
	# Creation of migration commands.
	#
	# Create a list of migration commands that are effective to working towards
	# balancing the extents in the SVC cluster.  Iterates through every
	# combination of VDisk/MDisk, attempting to "push" extents from the VDisk on 
	# the subject MDisk to another MDisk.  When a migrate is added, the MDisk is
	# removed from the list.
	#
	foreach my $vdisk_id (keys %$vdisk_ref) {

		if ($flagDebug) { 
			timestamp ();
			message (">| Checking VDisk: ".
				$vdisk_ref->{$vdisk_id}->{'name'}."."); 
		}

		my @source_list = keys %$mdisk_ref; push @source_list, "dummy";
		my @target_list = keys %$mdisk_ref; push @target_list, "dummy";
		
		for (my $source_id = shift @source_list; scalar @source_list; 
				$source_id = shift @source_list) {
				
			if ($flagDebug) { message (
				"-->| Checking source MDisk: ".
				$mdisk_ref->{$source_id}->{'name'}."."); 
			}	
			
			my @copy_list = @target_list;
			
			TARGET: for (my $target_id = shift @copy_list; scalar @copy_list;
					$target_id = shift @copy_list) {	
				
				if ($flagDebug) { message (
					"---->| Checking target MDisk: ".
					$mdisk_ref->{$target_id}->{'name'}."."); 
				}
			
				for (my $copies=0; $copies<2; $copies++) {
					next if (($copies == 1) && (!exists $extent_ref->{$source_id}->{$vdisk_id}->{1}));

					# Extents can be pushed away from the source MDisk to the target 
					# MDisk if:
					# 
					#  * The source isn't locked by a migrate.
					#  * There are more extents than optimal on the source media.
					#  * There are fewer extents than optimal on the target media.
					#
					# If these conditions are met, then the number of extents to be
					# transferred is equal to the lowest of:
					# 
					#  * Source extents minus optimal extents.
					#  * Target extents minus optimal extents.
					#  * Target free extents.
					#
					# The data structure are updated by subtracting the calculated
					# difference from the source's extents and the target's free
					# extents.  The command to run this migrate is then compiled 
					# and added to the list.
					# 
					if (!$extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'locked'}
						&& !$extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'locked'}
						&& $extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'extents'}
						> $extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'optimal'}
						&& $extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'extents'}
						< $extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'optimal'}) {

						my $source_diff = 
							$extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'extents'} - 
							$extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'optimal'};
						
						my $target_diff = 
							$extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'optimal'} -
							$extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'extents'};

						my $diff = ($source_diff < $target_diff) ? 
							$source_diff : $target_diff;

						# Check free space.  If there is insufficient space in the 
						# source MDisk, reduce the amount of $diff.
						# 
						if ($mdisk_ref->{$target_id}->{'free extents'} < $diff) {
							$diff = $mdisk_ref->{$target_id}->{'free extents'}
									or next;
						}

						# Check the migration flags.  If either source or target
						# is flagged move on to the next target/source.
						#
						if ($extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'locked'}
							|| $extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'locked'}){
							next;
						}
					
						# Decrease the target mdisk's free space, increase the 
						# target's free space.
						#
						$mdisk_ref->{$source_id}->{'alt extents'} += $diff;
						$mdisk_ref->{$target_id}->{'alt extents'} -= $diff;
					
						$mdisk_ref->{$target_id}->{'free extents'} -= $diff;
					
						# Decrease the source extents, increase the target extents.
						#
						$extent_ref->{$source_id}->{$vdisk_id}->{$copies}->{'extents'} 
							-= $diff;

						$extent_ref->{$target_id}->{$vdisk_id}->{$copies}->{'extents'}
							+= $diff;
					
						# Create the migration hash and push it to the list.
						#
						push @migrates, [
							"migrateexts",
							{
								"source" => $source_id,
								"target" => $target_id,
								"exts" => $diff,
								"vdisk" => $vdisk_id,
								"copy" => $copies,
								"threads" => 1
							},
							$n
						];
					
						# Used in non-execute recursive mode.  Allows us to
						# distinguish between cycles where migrates have been
						# added and cycles where migrates have not been added.
						#
						$flagPushed = 1;
					
						if ($flagDebug) { message (
							"------>| [PUSH] ".$diff." from ".
							$mdisk_ref->{$source_id}->{'name'}." to ".
							$mdisk_ref->{$target_id}->{'name'}."."
						); }
					
						# Do not create any more migrates involving the source or
						# target MDisk for this VDisk.
						# 
						@source_list = grep !/^[$source_id$target_id]$/, @source_list;
						@target_list = grep !/^[$source_id$target_id]$/, @target_list;

						last TARGET;
					}

				}
					
			}
				
		}
			
	}
	
	if ($flagDebug) { 
		timestamp ();
		message ("Finished migrate pass $n."); 
	}
	
	if ($flagExecute || !$flagRecursive) {
		last INNER;
	}
	
	# Check to see if the extents are balanced - loop through the $extent_ref
	# data structure checking if total extents are greater than or equal to
	# optimal extents.
	#
	my $flagBalanced = 1;

	foreach my $mdisk_id (keys %$mdisk_ref) {
		foreach my $vdisk_id (keys %$vdisk_ref) {
			for (my $copies=0; $copies<2; $copies++) {
				next if (($copies == 1) && (!exists $extent_ref->{$mdisk_id}->{$vdisk_id}->{1}));	
				if (!$extent_ref->{$mdisk_id}->{$vdisk_id}->{$copies}->{'locked'}
					&& ($extent_ref->{$mdisk_id}->{$vdisk_id}->{$copies}->{'extents'} < 
					$extent_ref->{$mdisk_id}->{$vdisk_id}->{$copies}->{'optimal'})) {

					$flagBalanced = 0;
				}
			}
		}
	}

	if ($flagDebug && !$flagPushed) {
		message ("No migrates added on this pass.");
	}
	
	if ($flagBalanced || !$flagPushed) { last INNER; }
	
	# Going around for another loop, so need to assign the new free extent
	# values to the MDisks.  Take the value held under 'alt extents' and
	# assign it as the value of 'free extents'.
	#
	foreach my $mdisk_id (keys %$mdisk_ref) {
		$mdisk_ref->{$mdisk_id}->{'free extents'} = 
			$mdisk_ref->{$mdisk_id}->{'alt extents'};
	}
	
	# End of the "inner" loop.
	#  -------------------------
	}	
	#  -------------------------
	#
	
	if ($flagDebug) { message (
		"Finished all migrate passes."
	); }

	# Check if any migration commands have been produced.
	#
	# If none have and the script is non-recursive or non-executing then
	# an error message is printed and the script terminates.
	#
	# Otherwise, the script moves into a waiting cycle until such a time
	# that more migrations can be produced or the operation successfully
	# completes.
	# 
	if (!@migrates) { 
		fatal ("No solution possible, check current migrates then".
			" ensure there is space available.", 5) 
		unless ($flagRecursive && $flagExecute);

		# Grab a list of migrates to be waited on.  This list will be compared
		# against a new list, with the script iterating whenever a migrate
		# finishes.
		# 
		if ($flagDebug) {timestamp();}
		my ($rc, $migr_ref) = $svc->svcinfo("lsmigrate");
		if ($rc) { fatal ($migr_ref, 3); }
		
		unless (scalar @$migr_ref) {
			fatal ("No solution possible.  Ensure there is space available.", 
					5);
		}
	
		$waiting_ref = $migr_ref;	
		next;
	}

	# If the user has not specified that these commands should be executed,
	# print them to the command line.  Otherwise, execute the commands and
	# return to the waiting cycle.
	# 
	if (!$flagExecute) {

		if ($flagDebug) { message (
			"Outputting migrates to command line."
		); }
			
		my $out = "";
		my $count;

		if ($numberMigr ) { $count = $numberMigr }
		else { $numberMigr = scalar (@migrates); } 

		# If the script is running in recursive mode, print all available
		# migration commands.  In non-recursive mode, only commands up to
		# the hard limit set by the user using --n are printed.
		#
		for (my $n = 0; 
				$n < ($flagRecursive ? scalar @migrates : $numberMigr); 
				$n++) {
			
			if ($migrates[$n]->[2] ne $migrates[$n-1]->[2] &&
				$flagRecursive) {
				$out .= "\n[Phase $migrates[$n]->[2]]\n";
			}
		
			$out .= "svctask " .$migrates[$n]->[0].
				" -source "    .$migrates[$n]->[1]->{'source'}.
				" -target "    .$migrates[$n]->[1]->{'target'}.
				" -exts "      .$migrates[$n]->[1]->{'exts'}.
				" -vdisk "     .$migrates[$n]->[1]->{'vdisk'}.
				" -copy "      .$migrates[$n]->[1]->{'copy'}.
				" -threads "   .$migrates[$n]->[1]->{'threads'}.
				"\n";
		}

		# The migrations commands are printed to the command line for the user
		# to run on the cluster as necessary.
		# 
		message ($out, 0);

		if ($flagDebug) { 
			timestamp ();
			message ("Finished script, exiting."); 
		}
		
		# All done!
		# 
		exit 0;
	}

	if ($flagDebug || $flagVerbose) { message (
		"Sending migrate commands to the SVC cluster."
	);}
	
	# Execute the commands.  
	# To do this we need to work out how many migrates we can run.
	# 
	my $tmpMigr = ($numberMigr or 32);

	# Get the migration info from the SVC again. Not really bothered if they've
	# changed in the intervening period since these were last checked - at this 
	# point all bets are off.
	# 
	if ($flagDebug) {timestamp();}
	my ($rc, $migr_info) = $svc->svcinfo("lsmigrate");
	fatal ($migr_info or "Unable to connect to SVC cluster.", 3) if $rc;
	
	# Subtract the number of processes running migrates at the moment.
	# 
	$tmpMigr -= scalar @$migr_info;

	if ($flagDebug) { message ("Limiting output to $tmpMigr commands."); }
	
	# Run the migrates - up to the number calculated above.  If the migrate
	# returns an error, attempt to run another.  
	# 
	for (my $n = $tmpMigr; $n > 0; $n--) {
			
		my $migr = shift @migrates;
		unless ($migr) { last; }

		message ("Sending: ".
			"svctask "  .$migr->[0].
			" -source " .$migr->[1]->{'source'}.
			" -target " .$migr->[1]->{'target'}.
			" -exts "   .$migr->[1]->{'exts'}.
			" -vdisk "  .$migr->[1]->{'vdisk'}.
			" -copy "   .$migr->[1]->{'copy'}.
			" -threads ".$migr->[1]->{'threads'}."\n");

		# Run the migrate command.
		# 
		if ($flagDebug) {timestamp();}
		my ($rc, $out_ref) = $svc->svctask ($migr->[0], $migr->[1]);
		if ($rc) {
			error ("Warning: Unable to run command, $out_ref");
			$n++; 
			next; 
		}
	}

	# Terminate a non-recursive execution of the script, operation has
	# completed.
	# 
	if (!$flagRecursive) {
		exit 0;
	}
	
	# Get a list of migrates to "watch" when the script iterates.  The script
	# will check an up to date list of migrates against this list to see if any
	# have finished.  When a migrate finishes, it will run the script again
	# to see if any further progress can be made.
	#
	if ($flagDebug) {timestamp();}
	my ($rc, $migr_info) = $svc->svcinfo("lsmigrate");
	fatal ($migr_info or "Unable to connect to SVC cluster.", 3) if $rc;

	# Make a list of migrates to monitor.  When one or more of these migrates
	# finish the script should run again.
	# 
	$waiting_ref = $migr_info;
}

# START RECURSIVE BLOCK
#  ----------------------------------------------------------------------------
#
$flagFirstRun = 0;

# End of recursive bit.
}
#
#  ----------------------------------------------------------------------------
# END RECURSIVE BLOCK
