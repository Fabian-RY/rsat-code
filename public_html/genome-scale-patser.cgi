#!/usr/bin/perl
if ($0 =~ /([^(\/)]+)$/) {
    push (@INC, "$`lib/");
}
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
require "RSA.lib";
require "RSA.cgi.lib";
$ENV{RSA_OUTPUT_CONTEXT} = "cgi";
require "genome-scale.lib.pl";
require "patser.lib.pl";

$patser_command = "$BIN/patser";
$matrix_from_transfac_command = "$SCRIPTS/matrix-from-transfac";
$matrix_from_gibbs_command = "$SCRIPTS/matrix-from-gibbs";
$convert_seq_command = "$SCRIPTS/convert-seq";
$features_from_patser_cmd = "$SCRIPTS/features-from-patser -v 1";
$add_orf_function_command = "$SCRIPTS/add-orf-function";
#$add_yeast_link_command = "$SCRIPTS/add-yeast-link";
$add_orf_function_command = "$SCRIPTS/add-orf-function";
$link_command = "$SCRIPTS/add-yeast-link";
$tmp_file_name = sprintf "genome-scale-patser.%s", &AlphaDate;

### Read the CGI query
$query = new CGI;

### print the header of the result page
&RSA_header("patser result ".$query->param("title"));

&ListParameters() if ($ECHO >= 2);

#### update log file ####
&UpdateLogFile();

&ReadRetrieveSeqParams();

&ReadPatserParameters();

### parameters for the piping to the feature map ###
$feature_file =  "$TMP/$tmp_file_name.ft";
#$features_from_patser_cmd .= " -seq $sequence_file";
#$features_from_patser_cmd .= " -o $feature_file";

&ReadPatserTableOutputFields();

#### return matching positions
#if ($query->param('positions')) {
#    $features_from_patser_cmd .= " -return matches";
#}
##
#### return score table
#if ($query->param('table')) {
#    $features_from_patser_cmd .= " -return table";
#}

$command = "$retrieve_seq_command $retrieve_seq_parameters ";
$command .= "| $patser_command $patser_parameters ";
$command .= "| $features_from_patser_cmd ";
#$command .= "| $add_orf_function_command -org $org ";


### execute the command ###
if ($query->param("output") =~ /display/i) {

#    if ($org eq "Saccharomyces_cerevisiae") { #### not yet supported for other organisms
#	$command .= "| $link_command  ";
#    }

    ### execute the command ###
    $result_file = "$TMP/$tmp_file_name.res";
    print "<PRE>$command</PRE>" if ($ECHO >= 1);
    open RESULT, "$command & |";

    unless ($query->param('table')) {
	&PipingWarning();
    }

    ### Print result on the web page
    print '<H2>Result</H2>';
    &PrintHtmlTable(RESULT, $result_file, true);
    close(RESULT);

    unless ($query->param('table')) {
	&PipingForm();
    }

    print "<HR SIZE = 3>";
    
} elsif ($query->param('output') =~ /server/i) {
    &ServerOutput("$command $parameters", $query->param('user_email'));
} else {
    &EmailTheResult($command, $query->param('user_email'));
}


print $query->end_html;


exit(0);

sub PipingForm {
  ### prepare data for piping
  $title = $query->param("title");
  $title =~ s/\"/'/g;
  print <<End_of_form;
<HR SIZE = 3>
<CENTER>
<TABLE>
<TR>
<TD>
<H3>Next step</H3>
</TD>
<TD>
<FORM METHOD="POST" ACTION="feature-map_form.cgi">
<INPUT type="hidden" NAME="title" VALUE="$title">
<INPUT type="hidden" NAME="feature_file" VALUE="$result_file">
<INPUT type="hidden" NAME="format" VALUE="patser">
<INPUT type="hidden" NAME="fill_form" VALUE="on">
<INPUT type="submit" VALUE="feature map">
</FORM>
</TD>
</TR>
</TABLE>
</CENTER>
End_of_form
}
