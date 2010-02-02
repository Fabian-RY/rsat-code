#!/usr/bin/perl
#### redirect error log to a file
if ($0 =~ /([^(\/)]+)$/) {
  push (@INC, "$`lib/");
}
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

#### TEMPORARY

$command = "$SCRIPTS/compare-features";
$tmp_file_name = sprintf "compare-features.%s", &AlphaDate();

### Read the CGI query
$query = new CGI;

### print the result page
&RSA_header("compare-features result", "results");
&ListParameters() if ($ENV{rsat_echo} >=2);

#### update log file ####
&UpdateLogFile();

#### read parameters ####
$parameters = " -v 1";

#### return a confusion table
# if ($query->param('return') eq "matrix") {
#     $parameters .= " -matrix"; 
# } 

### fields to return
$return_fields = " -return ";

### statistics
if ($query->param('stats')) {
    $return_fields .= "stats,";
} 

### intersection
if ($query->param('inter')) {
    $return_fields .= "inter,";
}

### differences
if ($query->param('diff')) {
	$return_fields .= "diff,";
}

### lower threshold on interection leength (size)
if ($query->param('inter_len') =~ /^\d+$/) {
  $inter_len = $query->param('inter_len');
  if (&IsNatural($inter_len)) {
    $parameters .= " -lth inter_len ".$inter_len;
  } else {
    &FatalError("Lower threshold on inter_len: $inter_len invalid value.");
  }
}

### lower threshold on interection leength (size)
if ($query->param('inter_cov') =~ /^\d+$/) {
  $inter_cov = $query->param('inter_cov');
  if (&IsReal($inter_cov)) {
    $parameters .= " -lth inter_cov ".$inter_cov;
  } else {
    &FatalError("Lower threshold on inter_cov: $inter_cov invalid value.");
  }
}


#### load the query feature file
$uploaded_file = $query->param('upload_ref_features');
if ($uploaded_file) {
    $tmp_query_features = "${TMP}/${tmp_file_name}_upload_query_features.tab";
    $upload_query_features = $query->param('upload_query_features');
    if ($upload_query_features) {
	if ($upload_file =~ /\.gz$/) {
	    $tmp_query_features .= ".gz";
	}
	$type = $query->uploadInfo($upload_query_features)->{'Content-Type'};
	open FEATURES, ">$tmp_query_features" ||
	  &cgiError("Cannot store query feature file in temp dir.");
	while (<$upload_query_features>) {
	    print FEATURES;
	}
	close FEATURES;
    }

## pasted query features
}elsif ($query->param('featQ') =~/\S/) {
    $tmp_query_features = "${TMP}/${tmp_file_name}_pasted_query_features.tab";
    open FEATURES, "> $tmp_query_features";
    print FEATURES $query->param('featQ');
    close FEATURES;
    &DelayedRemoval($tmp_query_features);
}else {
    &FatalError ("Please select the query feature file on your hard drive with the Browse button or paste features in the text area");
}
$parameters .= " -i $tmp_query_features";

#### load the reference feature file
$uploaded_file = $query->param('upload_ref_features');
if ($uploaded_file) {
    $tmp_ref_features = "${TMP}/${tmp_file_name}_uploaded_ref_features.tab";
    $upload_ref_features = $query->param('upload_ref_features');
    if ($upload_ref_features) {
	if ($upload_file =~ /\.gz$/) {
	    $tmp_ref_features .= ".gz";
	}
	$type = $query->uploadInfo($upload_ref_features)->{'Content-Type'};
	open FEATURES, ">$tmp_ref_features" ||
	  &cgiError("Cannot store expected frequency file in temp dir.");
	while (<$upload_ref_features>) {
	    print FEATURES;
	}
	close FEATURES;
    }
} elsif ($query->param('featRef') =~/\S/) {
    $tmp_ref_features = "${TMP}/${tmp_file_name}_pasted_ref_features.tab";
    open FEATURES, "> $tmp_query_features";
    print FEATURES $query->param('featRef');
    close FEATURES;
    &DelayedRemoval($tmp_ref_features);
}else {
    &FatalError ("Please select the reference feature file on your hard drive with the Browse button or paste features in the text area");
}
$parameters .= " -ref $tmp_query_features";


print "<PRE>command: $command $return_fields $parameters<P>\n</PRE>" if ($ENV{rsat_echo} >=1);

if ($query->param('output') =~ /display/i) {

#    &PipingWarning();

    ### execute the command ###
    $result_file = "$TMP/${tmp_file_name}.res";
    open RESULT, "$command $parameters $return_fields |";

    ### Print result on the web page
    print '<H2>Result</H2>';
    &PrintHtmlTable(RESULT, $result_file, true);
    close(RESULT);

#    &PipingForm();
    print '<HR SIZE=3>';

} elsif ($query->param('output') =~ /server/i) {
    &ServerOutput("$command $parameters $return_fields", $query->param('user_email'), $tmp_file_name);
} else {
    &EmailTheResult("$command $parameters", $query->param('user_email'), $tmp_file_name);
}

print $query->end_html;

exit(0);


