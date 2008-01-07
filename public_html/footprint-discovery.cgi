#!/usr/bin/perl
if ($0 =~ /([^(\/)]+)$/) {
    push @INC, "$`lib/";
}
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
require "RSA.lib";
require "RSA2.cgi.lib";

$ENV{RSA_OUTPUT_CONTEXT} = "cgi";
$command = "$SCRIPTS/footprint-discovery";
$tmp_file_name = sprintf "footprint-discovery.%s", &AlphaDate();
$result_dir = $TMP."/".$tmp_file_name;
$result_dir =~ s|\/\/|\/|g;
`mkdir -p $result_dir`;
$file_prefix = $result_dir."/footprints";
$query_file = $file_prefix."_genes";

#$ENV{rsat_echo}=2;

### Read the CGI query
$query = new CGI;

### Print the header
&RSA_header("footprint-discovery result", "results");

#### update log file ####
&UpdateLogFile();

&ListParameters() if ($ENV{rsat_echo} >= 2);

#### read parameters ####
$parameters = " -v 1 -index ";

################################################################
#### queries
if ( $query->param('queries') =~ /\S/) {
    open QUERY, ">".$query_file;
    print QUERY $query->param('queries');
    close QUERY;
    &DelayedRemoval($query_file);
    $parameters .= " -i ".$query_file;
} else {
    &cgiError("You should enter at least one query in the box\n");
}

################################################################
#### organism
my $organism = "";
unless ($organism = $query->param('organism')) {
    &cgiError("You should specify a query organism");
}
unless (defined(%{$supported_organism{$organism}})) {
    &cgiError("Organism $org is not supported on this site");
}
$parameters .= " -org $organism";


################################################################
#### Taxon
my $taxon = "";
unless ($taxon = $query->param('taxon')) {
    &cgiError("You should specify a taxon");
}
$parameters .= " -taxon $taxon";


## ##############################################################
## Thresholds
my @parameters = $query->param();
foreach my $param (@parameters) {
    if ($param =~ /^return_(.+)/) {
	my $field = $1;
	$parameters .= " -return ".$field;
    } elsif ($param =~ /^lth_(.+)/) {
	my $field = $1 ;
	my $value = $query->param($param);
	next unless (&IsReal($value));
	$parameters .= " -lth ".$field." ".$value;
    } elsif ($param =~ /^uth_(.+)/) {
	my $field = $1 ;
	my $value = $query->param($param);
	next unless (&IsReal($value));
	$parameters .= " -uth ".$field." ".$value;
    }
}


$parameters .= " -o ".$file_prefix;

## Report the command
print "<PRE>$command $parameters </PRE>" if ($ENV{rsat_echo} >= 1);

################################################################
#### run the command
#if ($query->param('output') eq "display") {
#    &PipingWarning();
#
#    open RESULT, "$command $parameters |";
#
#    print '<H2>Result</H2>';
#    &PrintHtmlTable(RESULT, $result_file, true);
#    close(RESULT);
#
#    &PipingForm();
#
#    print "<HR SIZE = 3>";
#} elsif ($query->param('output') =~ /server/i) {
#    &ServerOutput("$command $parameters", $query->param('user_email'));
#} else { 
$index_file = $tmp_file_name."/footprints_index.html";
&EmailTheResult("$command $parameters", $query->param('user_email'), $index_file);
#&EmailTheResult("$command $parameters", $query->param('user_email'));
#}
print $query->end_html();

exit(0);


################################################################
#
# Pipe the result to other commands
#
sub PipingForm {
    my $genes = `cat $result_file`;
    ### prepare data for piping
    print <<End_of_form;
<HR SIZE = 3>
<TABLE class = 'nextstep'>
<TR>

<TD>
<H3>Next step</H3>
</TD>

</tr>
<tr>
<TD>
<FORM METHOD="POST" ACTION="retrieve-seq_form.cgi">
<INPUT type="hidden" NAME="organism" VALUE="$organism">
<INPUT type="hidden" NAME="single_multi_org" VALUE="multi">
<INPUT type="hidden" NAME="seq_label" VALUE="gene identifier + organism + gene name">
<INPUT type="hidden" NAME="genes" VALUE="selection">
<INPUT type="hidden" NAME="gene_selection" VALUE="$genes">
<INPUT type="hidden" NAME="ids_only" VALUE="checked">
<INPUT type="submit" value="retrieve sequences">
</FORM>
</TD>
</TR>
</TABLE>
End_of_form

}

