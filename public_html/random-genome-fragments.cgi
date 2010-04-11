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
$command = "$SCRIPTS/random-genome-fragments";
$tmp_file_name = sprintf "random-genome-fragments.%s", &AlphaDate;

### Read the CGI query
$query = new CGI;

### print the header
&RSA_header("Random genome fragments result", "results");

#### update log file ####
&UpdateLogFile;

&ListParameters() if ($ENV{rsat_echo} >= 2);


############################################################
#### read parameters ####
$parameters = "";

############################################################
## Random fragments

#### template file (optional)
($template_sequence_file, $template_sequence_format) = &MultiGetSequenceFile(1, "$TMP/$tmp_file_name"."_template.fa", 0);

## a template file has been given
if ($template_sequence_file) { 
  ## calculates the sequence lengths from the input sequence file
  my $length_file = "$TMP/$tmp_file_name".".lengths";
  my $seqlength_cmd = "$SCRIPTS/sequence-lengths -v 1 -i ".$template_sequence_file." -o ".$length_file;
  `$seqlength_cmd`;
  $parameters .= " -lf $length_file ";
} else {
  #### number of fragments
  $frag_nb = $query->param('frag_nb');
  if (&IsNatural($frag_nb)) {
    $parameters .= " -r $frag_nb ";
  } else {
    &FatalError("Fragment number must be a natural number");
  }

  #### length of fragments
  $frag_length = $query->param('frag_length');
  if (&IsNatural($frag_length)) {
    $parameters .= " -l $frag_length ";
  } else {
    &FatalError("Fragment length must be a natural number");
  }
}

############################################################
## Organims

#### organism 
if ($query->param('org_select')) {
  ## RSAT organism
  if ($query->param('org_select') eq "rsat_org"){
    unless ($organism = $query->param('organism')) {
      &FatalError("You should specify an organism");
    }
    if (defined(%{$supported_organism{$organism}})) {
      $parameters .= " -org $organism ";
    } else {
      &FatalError("Organism $organism is not supported on this site");
    }

    ## EnsEMBL organism
  } elsif ($query->param('org_select') eq "ensembl_org") {
    unless ($organism_ens = $query->param('organism_ens')) {
      &FatalError("You should specify an Ensembl organism");
    }
    $parameters .= " -org_ens $organism_ens ";
  }
}

############################################################
## Output
if ($query->param('outputformat')) {

  ## return sequence
  if ($query->param('outputformat') eq "outputseq"){
    ## not compatible with non-RSAT organisms
    if ($query->param('org_select') ne "rsat_org") {
      &FatalError("Sequence output is only compatible with RSAT organisms. Select a RSAT organism or choose as output format 'genomic coordinates' ");
    } else {
      $parameters .= " -return seq ";
    }

    ## return coordinates
  } elsif ($query->param('outputformat') eq "outputcoord") {
    if ($query->param('coord_format')) {
      $parameters .= " -return coord -coord_format ".$query->param('coord_format');
      $parameters .= " -v 1 ";
    }
  }
}

## repeats
if ($query->param('rm') =~ /on/) {
  $parameters .= " -rm ";
}

############################################################
## Command

print "<PRE>command: $command $parameters <P>\n</PRE>"  if ($ENV{rsat_echo} >= 1);

### execute the command ###
open RESULT, "$command $parameters |";

if (($query->param('output') =~ /display/i) ||
    ($query->param('output') =~ /server/i)) {
  &PipingWarning();

   ### print the result
    print '<H4>Result</H4>';

  ### open the sequence file on the server
  $sequence_file = "$TMP/$tmp_file_name.res";
  if (open MIRROR, ">$sequence_file") {
    $mirror = 1;
    &DelayedRemoval($sequence_file);
  }

  print "<PRE>";
  while (<RESULT>) {
    print "$_" unless ($query->param('output') =~ /server/i);
    print MIRROR $_ if ($mirror);
  }
  print "</PRE>";
  close RESULT;
  close MIRROR if ($mirror);

  $result_URL = "$ENV{rsat_www}/tmp/${tmp_file_name}.res";
  print ("The result is available at the following URL: ", "\n<br>",
	 "<a href=${result_URL}>${result_URL}</a>",
	 "<p>\n");

  ### prepare data for piping
  if ($query->param('outputformat') eq "outputseq"){
    $out_format = "fasta"; ## Fasta is the only supported format, but it is necessary to specify it for the piping form
    &PipingFormForSequence();
  } elsif ($query->param('coord_format') eq "bed") {
    &PipingForm();
  }

  print "<HR SIZE = 3>";

} else {
  &EmailTheResult("$command $parameters", $query->param('user_email'));
}

print $query->end_html;

exit(0);

############################################
sub PipingForm {
	my $assembly = `grep Ensembl $TMP/$tmp_file_name.res `;
	$assembly =~ s/.*assembly:(.*)$/$1/;
    ### prepare data for piping
    print <<End_of_form;
<TABLE class='nextstep' style='text-align:left'>
<TR>
  <TD>
    <H3>Next step</H3>
  </TD>
  </tr>
  <tr  style='text-align:left'>
  <TD  style='text-align:left'>

<b>Extract sequences in batch with Galaxy</b>.
<br/>
For the moment, we cannot directly connect this BED file to Galaxy, and retrieve the sequences automatically.
<p/>
Here are some <b>instructions to easily retrieve these sequences: </b>
<ol>
<li><a href="http://main.g2.bx.psu.edu/root?tool_id=upload1" target="_blank">Open The Galaxy website in a new window </a></li>

<li>The selected tool is "Upload file". Fill the form as follow: <br/>
<b>File Format: BED</b> <br/>
<b>URL/Text:</b>  Paste the URL of your result file: <b>${result_URL}</b><br/>
<b>Genome:</b>  Type the name of the organism assembly: <b>$assembly</b><br/>
Click on the "execute" button. This job is queued (right menu). Wait until it is finished (time varies depending on the server load).
</li>
<li>In the left menu, click on "Fetch Sequences" and on "Extract Genomic DNA"</li>
<li>The form is automatically filled, click on the "execute" button</li>
<li>Your sequences are downloadable from the right menu.</li>
</ol>
</TD>
</TR>
</TABLE>
End_of_form
}



