#!/usr/bin/perl
if ($0 =~ /([^(\/)]+)$/) {
    push (@INC, "$`lib/");
}
#require "cgi-lib.pl";
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
#### redirect error log to a file
#BEGIN {
#    $ERR_LOG = "/dev/null";
##    $ERR_LOG = "$TMP/RSA_ERROR_LOG.txt";
#    use CGI::Carp qw(carpout);
#    open (LOG, ">> $ERR_LOG")
#	|| die "Unable to redirect log\n";
#    carpout(*LOG);
#}
require "RSA.lib";
require "RSA2.cgi.lib";
$ENV{RSA_OUTPUT_CONTEXT} = "cgi";
$command = "$SCRIPTS/convert-matrix";
$tmp_file_name = sprintf "convert-matrix.%s", &AlphaDate();
$result_file = "$TMP/$tmp_file_name.res";
$ENV{rsat_echo} = 1;

### Read the CGI query
$query = new CGI;

### print the header
&RSA_header("convert-matrix result", 'results');

#### update log file ####
&UpdateLogFile();

&ListParameters() if ($ENV{rsat_echo} >= 2);

#### read parameters ####
local $parameters;

################################################################
#### Matrix specification
$matrix_file = "$TMP/$tmp_file_name.input";
if ($query->param('matrix')) {
    open MAT, "> $matrix_file";
    print MAT $query->param('matrix');
    close MAT;
    &DelayedRemoval($matrix_file);
    
    $parameters .= " -i $matrix_file";
} else {
    &RSAT::error::FatalError('You did not enter any data in the matrix box');
}

################################################################
## Compute reverse complement
if ($query->param('rc')) {
  $parameters .= " -rc";
}

################################################################
## Pseudo-counts
if (&IsReal($query->param('pseudo_counts'))) {
    $parameters .= " -pseudo ".$query->param('pseudo_counts');
} else {
    &FatalError("Pseudo-count should be a real number");
}
if ($query->param('pseudo_distribution') eq "equi_pseudo") {
    $parameters .= " -equi_pseudo ";
}

################################################################
## decimals
if (&IsInteger($query->param('decimals'))) {
    $parameters .= " -decimals ".$query->param('decimals');
} else {
    &FatalError("Decimals should be an integer number");
}

################################################################
## permutations
if (&IsInteger($query->param('perm'))) {
    $parameters .= " -perm ".$query->param('perm');
}


################################################################
## Matrix input format

local $input_format = lc($query->param('matrix_format'));
($input_format) = split (/\s+/, $input_format);
#$input_format =~ s/cluster\-buster/cb/i;
#$input_format =~ s/(\S+)/$1/; ## Only retain the first word
$parameters .= " -from ".$input_format;


################################################################
## Background model method
local $bg_method = $query->param('bg_method');
if ($bg_method eq "from_matrix") {

} elsif ($bg_method eq "bgfile") {
  ## Select pre-computed background file in RSAT genome directory
  local $organism_name = $query->param("organism");
  local $noov = "ovlp";
  local $background_model = $query->param("background");
  local $oligo_length = 1;
  $bg_file = &ExpectedFreqFile($organism_name,
			       $oligo_length, $background_model,
			       noov=>$noov, str=>"-1str");
  $parameters .= " -bgfile ".$bg_file;

} elsif ($bg_method =~ /upload/i) {
  ## Upload user-specified background file
  local $bgfile = "${TMP}/${tmp_file_name}_bgfile.txt";
  local $upload_bgfile = $query->param('upload_bgfile');
  if ($upload_bgfile) {
    if ($upload_bgfile =~ /\.gz$/) {
      $bgfile .= ".gz";
    }
    local $type = $query->uploadInfo($upload_bgfile)->{'Content-Type'};
    open BGFILE, ">$bgfile" ||
      &cgiError("Cannot store background file in temp dir.");
    while (<$upload_bgfile>) {
      print BGFILE;
    }
    close BGFILE;
    $parameters .= " -bgfile $bgfile";
    $parameters .= " -bg_format ".$query->param('bg_format');
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
## Matrix output format
local $output_format = lc($query->param('output_format'));
$parameters .= " -to ".$output_format;

## Return fields
local @return_fields = ();
foreach my $stat qw (counts frequencies weights info consensus parameters profile margins logo) {
  if ($query->param($stat)) {
    push @return_fields, $stat;
    if ($stat eq "logo"){
      $parameters .= " -v 1 -logo_dir $ENV{RSAT}/public_html/tmp ";
      $parameters .= " -logo_format png,pdf ";
      # seqlogo options
      if ($query->param("error_bar")){
	$parameters .= " -logo_opt '-e' ";
      }
      if ($query->param("small_correc")){
	$parameters .= " -logo_opt '-M' ";
      }
      if ($query->param("stretch")){
	$parameters .= " -logo_opt '-S' ";
      }
    }
  }
}

if ($output_format eq 'tab') {
    $parameters .= " -v 1 ";
    $parameters .= " -return ";
    $parameters .= join ",", @return_fields;
}else {
    $parameters .= " -to ".$output_format;
    $parameters .= " -return counts";
}
$parameters .= " -o $result_file";

print "<PRE>command: $command $parameters<P>\n</PRE>" if ($ENV{rsat_echo} >= 1);

### execute the command ###
if ($query->param('output') eq "display") {
#    &PipingWarning();

 ## prepare figures
    ### prepare data for piping
 #   open RESULT, "$command $parameters |";
  &doit("$command $parameters"); ## DEBUG test
  open RESULT, "$result_file";  ## DEBUG

  print '<H4>Result</H4>';
  print '<PRE>';
  while (<RESULT>) {
    #	s|${TMP}/||g;
      #	s|${BIN}/||g;
      next if ($_ =~ /logo file:(.*)\.pdf$/);
      if ($_ =~ /logo file:(.*)\.png$/){
	(local $logo = $1 )=~ s|${TMP}| ${WWW_TMP}|g;
#	print "<IMG SRC=\"$logo\">\n";
	$logo =~ s/\.png//;
	print "<a href = \"$logo.pdf\"><IMG SRC=\"$logo\.png\" ></a>\n";
	print "<br/>";
	&DelayedRemoval("$TMP/$1");
      }
	else {
		print $_;
	}
#	$genes .= $_;
    }
    print '</PRE>';
    close(RESULT);

  &PipingForm();

    print "<HR SIZE = 3>";
} elsif ($query->param('output') =~ /server/i) {
    &ServerOutput("$command $parameters", $query->param('user_email',$result_file));
} else {
    &EmailTheResult("$command $parameters", $query->param('user_email'),$result_file);
}
print $query->end_html;

exit(0);


### prepare data for piping
sub PipingForm {
  local $command = "$ENV{RSAT}/perl-scripts/convert-matrix -i $result_file -from tab -to tab -top 1 -return counts";
  local $matrix_content = `$command`;
  $matrix_content =~ s|//\n||gm;
  $matrix_content =~ s|;.*\n||gm;
#  print "<pre>".$command."</pre>";
#  print "<pre>".$matrix_content."</pre>";

  $title = $query->param('title');
  $title =~ s/\"/\'/g;
    print <<End_of_form;
<hr size="3">
<table class="Nextstep">
<tr>
<td colspan="3">
<h3>Next step</h3>
</td>
</tr>

<tr>
<!--
<td valign="bottom" align="center">
<form method="post" action="patser_form.cgi">
<input type="hidden" name="title" value="$title">
<input type="hidden" name="matrix_file" value="$tab_result_file">
<input type="hidden" name="matrix_format" value="tab">
<input type="submit" value="pattern matching (patser)">
</form>
</td>
-->

<td valign="bottom" align="center">
<b><font color=red>new</a></b>
<form method="POST" action="matrix-scan_form.cgi">
<input type="hidden" name="title" value="$title">
<input type="hidden" name="matrix_file" value="$result_file">
<input type="hidden" name="matrix_format" value="$output_format">
<input type="submit" value="pattern matching (matrix-scan)">
</form>
</td>

<td valign=bottom align=center>
<form method="post" action="convert-matrix_form.cgi">
<input type="hidden" name="title" value="$title">
<input type="hidden" name="matrix_file" value="$result_file">
<input type="hidden" name="matrix_format" value="$output_format">
<input type="hidden" name="logo" value="on" checked="checked">
<input type="submit" value="convert-matrix">
</form>
</td>

<td valign=bottom align=center>
<form method="post" target='_blank' action="http://meme.nbcr.net/meme4/cgi-bin/tomtom.cgi">
<input type="hidden" name="query" value="$matrix_content">
<input type="hidden" name="DIST" value="sandelin">
<input type="submit" value="TOMTOM">
</form>
Compare a single matrix to a motif database.
</td>
</tr>

</table>
End_of_form

}
