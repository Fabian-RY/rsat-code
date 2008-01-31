#!/usr/bin/perl
if ($0 =~ /([^(\/)]+)$/) {
    push (@INC, "$`lib/");
}
#require "cgi-lib.pl";
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
#### redirect error log to a file
BEGIN {
    $ERR_LOG = "/dev/null";
#    $ERR_LOG = "$TMP/RSA_ERROR_LOG.txt";
    use CGI::Carp qw(carpout);
    open (LOG, ">> $ERR_LOG")
	|| die "Unable to redirect log\n";
    carpout(*LOG);
}
require "RSA.lib";
require "RSA2.cgi.lib";
$ENV{RSA_OUTPUT_CONTEXT} = "cgi";
$command = "$SCRIPTS/convert-background-model -v 1 ";
$tmp_file_name = sprintf "convert-background-model.%s", &AlphaDate();
$result_file = "$TMP/$tmp_file_name.res";
$ENV{rsat_echo} = 1;

### Read the CGI query
$query = new CGI;

### print the header
&RSA_header("convert-background-model result", 'results');

#### update log file ####
&UpdateLogFile();

&ListParameters() if ($ENV{rsat_echo} >= 2);

#### read parameters ####
my $parameters;


################################################################
## Background model method
my $bg_method = $query->param('bg_choose');
if ($bg_method eq "rsat") {
    ## Select pre-computed background file in RSAT genome directory
    
    #my $bg_taxo = $query->param('bg_taxo');
    #if ($bg_taxo eq "organism"){
    	my $organism_name = $query->param("organism");
    	$parameters .= " -org ".$organism_name;
    #}
    
    my $background_model = $query->param("background");
    $parameters .= " -bg ".$background_model;

  	my $markov_order = $query->param('markov_order');
  	&RSAT::error::FatalError("Markov model should be a Natural number") unless &IsNatural($markov_order);
  	$parameters .= " -markov ".$markov_order;
    
    my $strands = $query->param('strands');
      if ($strands=~/single/) {
    	$parameters .= " -1str ";
    }	
    	
    if ($strands=~/both/) {
    	$parameters .= " -2str ";
    }
    
    if ($query->param('noov')) {
    	 $parameters .= " -noov ";
    }
    
#    $bg_file = &ExpectedFreqFile($organism_name,
#				 $oligo_length, $background_model,
#				 noov=>$noov, str=>$str);
#    $parameters .= " -bgfile ".$bg_file;
    $parameters .= " -from oligo-analysis";
    
} elsif ($bg_method =~ /upload/i) {
    ## Upload user-specified background file
    my $bgfile = "${TMP}/${tmp_file_name}_bgfile.txt";
    my $upload_bgfile = $query->param('upload_bgfile');
    if ($upload_bgfile) {
	if ($upload_bgfile =~ /\.gz$/) {
	    $bgfile .= ".gz";
	}
	my $type = $query->uploadInfo($upload_bgfile)->{'Content-Type'};
	open BGFILE, ">$bgfile" ||
	    &cgiError("Cannot store background file in temp dir.");
	while (<$upload_bgfile>) {
	    print BGFILE;
	}
	close BGFILE;
	$parameters .= " -i $bgfile";
	$parameters .= " -from ".$query->param('bg_format');
    } else {
	&FatalError ("If you want to upload a background model file, you should specify the location of this file on your hard drive with the Browse button");
    }
    
} else {
    &RSAT::error::FatalError($bg_method," is not a valid method for background specification");
}


################################################################
## bg_pseudo
if (&IsReal($query->param('bg_pseudo'))) {
    $parameters .= " -bg_pseudo ".$query->param('bg_pseudo');
}


################################################################
## decimals
if (&IsInteger($query->param('decimals'))) {
    $parameters .= " -decimals ".$query->param('decimals');
} else {
    &FatalError("Decimals should be an integer number");
}


################################################################
## Matrix output format
my $output_format = lc($query->param('output_format'));
$parameters .= " -to ".$output_format;

print "<PRE>command: $command $parameters<P>\n</PRE>" if ($ENV{rsat_echo} >= 1);

### execute the command ###
if ($query->param('output') eq "display") {
#    &PipingWarning();

 ## prepare figures
    ### prepare data for piping
    open RESULT, "$command $parameters |";
    
    print '<H4>Result</H4>';
    print '<PRE>';
    while (<RESULT>) {
		print $_;
    }
    print '</PRE>';
    close(RESULT);

#    &PipingForm();

    print "<HR SIZE = 3>";
    
} elsif ($query->param('output') =~ /server/i) {
    &ServerOutput("$command $parameters", $query->param('user_email'));
} else {
    &EmailTheResult("$command $parameters", $query->param('user_email'));
}
print $query->end_html;

exit(0);

