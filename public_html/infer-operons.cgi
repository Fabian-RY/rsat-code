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

$tmp_file_name = sprintf "infer-operon.%s", &AlphaDate();

### Read the CGI query
$query = new CGI;

### print the header
&RSA_header("infer-operon result", 'results');

#### update log file ####
&UpdateLogFile();
&ListParameters() if ($ENV{rsat_echo} >= 2);

$parameters = "";

################################################################
## Single or multi-genome query
# if ($query->param('single_multi_org') eq 'multi') {
#     $command = "$SCRIPTS/infer-operon-multigenome";

#     &cgiMessage(join("<P>",
# 		     "The computation can take a more or less important time depending on the taxon size.",
# 		     "If the answer does not appear in due time, use the option <i>output email</i>"));
# } else {
     $command = "$SCRIPTS/infer-operon";

# }



#### organism
$organism = $query->param('organism');
if (defined($supported_organism{$organism})) {
    $organism_name = $supported_organism{$organism}->{'name'};

    $parameters .= " -org ".$organism unless ($query->param('single_multi_org') eq 'multi'); ## For multi-genome retrieval, the query organism name is passed to pattern discovery programs, but it is not necessary
} else {
    &cgiError("Organism '",
	      $organism,
	      "' is not supported on this web site.");
}



#### distance threshold
if (&IsInteger($query->param('dist_thr'))) {
    $parameters .= " -dist ".$query->param('dist_thr');
}


### return fields
my $i=0;
foreach my $field ("leader","trailer","operon","query","q_info","up_info","down_info") {
    my $return_field = "return_".$field;
#    my $return_field = $field;
    if ($query->param($return_field) eq "on"){
	$parameters .= " -return ".$field;
	$i++;
    }
}
&cgiError("Invalid output fields, please check at least one output field.") if ($i==0);

#### queries ####
if ($query->param('genes') eq "all") {
    ### take all genes as query
    $parameters .= " -all ";
} elsif ($query->param('uploaded_file')) {
    $upload_file = $query->param('uploaded_file');
    $gene_list_file = "${TMP}/${tmp_file_name}.genes";
    if ($upload_file =~ /\.gz$/) {
	$gene_list_file .= ".gz";
    }
    $type = $query->uploadInfo($upload_file)->{'Content-Type'};
    open SEQ, ">$gene_list_file" ||
	&cgiError("Cannot store gene list file in temporary directory");
    while (<$upload_file>) {
	print SEQ;
    }
    close SEQ;
    $parameters .= " -i $gene_list_file ";

} else {
    my $gene_selection = $query->param('gene_selection');
    $gene_selection =~ s/\r/\n/g;
    my @gene_selection = split ("\n", $gene_selection);
    if ($gene_selection =~ /\S/) {
	open QUERY, ">$TMP/$tmp_file_name";
	foreach my $row (@gene_selection) {
	    $row =~ s/ +/\t/; ## replace white spaces by a tab for the multiple genomes option. 
	    print QUERY $row, "\n";
	}
	close QUERY;
	&DelayedRemoval("$TMP/$tmp_file_name");
	$parameters .= " -i $TMP/$tmp_file_name";
    } else {
	&cgiError("You should enter at least one gene identifier in the query box..");
    }
}

print  "<PRE><B>Command :</B> $command $parameters</PRE><P>" if ($ENV{rsat_echo} >= 1);

################################################################
#### run the command
if ($query->param('output') eq "display") {
    &PipingWarning();

    open RESULT, "$command $parameters |";

    print '<H2>Result</H2>';
    &PrintHtmlTable(RESULT, $result_file, true);
    close(RESULT);

#    &PipingForm();

    print "<HR SIZE = 3>";
} elsif ($query->param('output') =~ /server/i) {
    &ServerOutput("$command $parameters", $query->param('user_email'));
} else { 
    &EmailTheResult("$command $parameters", $query->param('user_email'));
}
print $query->end_html();


exit(0);
