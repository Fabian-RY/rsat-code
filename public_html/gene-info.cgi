#!/usr/bin/perl
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
$command = "$SCRIPTS/gene-info";
$tmp_file_name = sprintf "gene-info.%s", &AlphaDate();
$result_file = "$TMP/$tmp_file_name.res";

### Read the CGI query
$query = new CGI;

#### update log file ####
&UpdateLogFile();

### Print the header
&RSA_header("gene-info result", "results");

#### read parameters ####
$parameters .= "";

################################################################
#### queries
if ( $query->param('queries') =~ /\S/) {
    open QUERY, ">$TMP/$tmp_file_name";
    print QUERY $query->param('queries');
    close QUERY;
    &DelayedRemoval("$TMP/$tmp_file_name");
    $parameters .= " -i $TMP/$tmp_file_name";
} else {
    &cgiError("You should enter at least one query in the box\n");
}

################################################################
### feature type
if ($query->param('feattype')) {
    my ($feattype) = split " ", $query->param('feattype'); ### take the first word
    $parameters .= " -feattype ".$feattype;
}

################################################################
#### full match
$parameters .= " -full" if ($query->param('full'));

################################################################
#### match queries against description
$parameters .= " -desc" if ($query->param('match_description'));

################################################################
#### organism
my $organism = "";
unless ($organism = $query->param('organism')) {
    &cgiError("You should specify an organism");
}
unless (defined(%{$supported_organism{$organism}})) {
    &cgiError("Organism $org is not supported on this site");
}
$parameters .= " -org $organism";


print "<PRE>$command $parameters </PRE>" if ($ENV{rsat_echo});

################################################################
#### run the command
if ($query->param('output') eq "display") {
    &PipingWarning();

    open RESULT, "$command $parameters |";

    print '<H2>Result</H2>';
    &PrintHtmlTable(RESULT, $result_file, 1);
    close(RESULT);

    &PipingForm();

    print "<HR SIZE = 3>";

} else {
    &EmailTheResult("$command $parameters", $query->param('user_email'));
}
print $query->end_html();

exit(0);


##############f##################################################
#
# Pipe the result to other commands
#
sub PipingForm {
    my $genes = `cat $result_file`;
    ### prepare data for piping
    print <<End_of_form;
<hr>
<table class='nextstep'>

<tr><td colspan=2>
<h3>Next step</h3>
</td></tr>

<tr>

<td><form method="post" action="retrieve-seq_form.cgi">
<input type="hidden" name="organism" VALUE="$organism">
<input type="hidden" name="genes" VALUE="selection">
<input type="hidden" name="gene_selection" VALUE="$genes">
<INPUT type="submit" value="retrieve sequences">
</form></td>

<td><form method="post" action="get-orthologs_form.cgi">
<input type="hidden" name="organism" VALUE="$organism">
<input type="hidden" name="queries" VALUE="$genes">
<INPUT type="submit" value="get orthologs">
</form></td>

</tr>


</TABLE>
End_of_form

}

