#!/usr/bin/perl
#### this cgi script fills the HTML form for the program matrix-clustering
BEGIN {
    if ($0 =~ /([^(\/)]+)$/) {
	push (@INC, "$`lib/");
    }
    require "RSA.lib";
}
#if ($0 =~ /([^(\/)]+)$/) {
#    push (@INC, "$`lib/");
#}
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
require "RSA.lib";
require "RSA2.cgi.lib";
$ENV{RSA_OUTPUT_CONTEXT} = "cgi";

### Read the CGI query
$query = new CGI;

################################################################
### default values for filling the form
$default{ref_db} = "CHECKED";
$default{demo_descr1} = "";
$default{matrix}="";
$default{matrix_file}="";
$default{matrix_format} = "transfac";
$default{hclust_method}="average";
$checked{$default{bg_method}} = "CHECKED";
$default{heatmap} = "CHECKED";
$default{labels} = "name";
$default{'return_w'} = "CHECKED"; $default{'lth_w'} = 5;
$default{'return_cor'} = "CHECKED"; $default{'lth_cor'} = "0.6";
$default{'return_Ncor'} = "CHECKED"; $default{'lth_Ncor'} = "0.4";
$default{'return_logoDP'} = "CHECKED";
$default{'return_NSW'} = "CHECKED";
$default{'return_NsEucl'} = "CHECKED";

### replace defaults by parameters from the cgi call, if defined
foreach $key (keys %default) {
  if ($query->param($key)) {
    $default{$key} = $query->param($key);
  }
  if ($query->param($key) =~ /checked/i) {
    $checked{$key} = "CHECKED";
  }
}



&ListParameters() if ($ENV{rsat_echo} >= 2);

################################################################
### print the form ###

################################################################
### header
&RSA_header("matrix-clustering", "form");
print "<CENTER>";
print "Measure the (dis)similarity between a set of motifs to identify clusters of similarities and align the motifs.<P>\n";
print "<br>Conception<sup>c</sup>, implementation<sup>i</sup> and testing<sup>t</sup>: ";
print "<a target='_blank' href='http://www.bigre.ulb.ac.be/Users/jvanheld/'>Jacques van Helden</a><sup>cit</sup>\n";
print ", <a target='_blank' href='http://www.bigre.ulb.ac.be/Users/morgane/'>Morgane Thomas-Chollier</a><sup>t</sup>\n";
print ", <a target='_blank' href='http://www.ibens.ens.fr/spip.php?article26&lang=en'>Denis Thieffry</a><sup>t</sup>\n";
print "and <a target='_blank' href='http://biologie.univ-mrs.fr/view-data.php?id=202'>Carl Herrmann</a><sup>ct</sup>\n";
print "and <a target='_blank'>Jaime Castro</a><sup>cit</sup>\n";
print "</CENTER>";

## demo description
print $default{demo_descr1};

print $query->start_multipart_form(-action=>"matrix-clustering.cgi");


################################################################
#### Matrix specification
print "<hr>";

################################################################
## Query matrices
&GetMatrix('title'=>'Query matrices', 'nowhere'=>1,'no_pseudo'=>1, consensus=>1);
print "<hr>";

################################################################
## Specific options for matrix-clustering

print "<h2>", "Clustering options", ,"</h2>";

## Hierarchical clusterting agglomeration rul
print "<b>Agglomeration rule</b>";
print "<B><A HREF='help.matrix-clustering.html#hclust_method'>  Aglomeration rule  </A>&nbsp;</B>\n";
print $query->popup_menu(-name=>'hclust_method',
 			 -Values=>["complete", "average", "single"],
 			 -default=>$default{hclust_method});
print "<hr>";


## Draw heatmap
print $query->checkbox(-name=>'heatmap',
  		       -checked=>$default{heatmap},
  		       -label=>'');
print "&nbsp;<A'><B>Draw a heatmap showing the distances between the motifs.</B></A>";
print "<BR>";
print "<HR width=550 align=left>\n";



################################################################
## Selection of output fields and thresholds
&PrintMatrixMatchingScores();

print "<h2>", "Display options", ,"</h2>";

print "<hr>";

################################################################
## Send results by email only
print "<p>\n";
&SelectOutput();

################################################################
## Action buttons
print "<UL><UL><TABLE class='formbutton'>\n";
print "<TR VALIGN=MIDDLE>\n";
print "<TD>", $query->submit(-label=>"GO"), "</TD>\n";
print "<TD>", $query->reset, "</TD>\n";
print $query->end_form;

################################################################
## Demo data
my $descr1 = "<H2>Comment on the demonstration example 1</H2>\n";
$descr1 .= "<blockquote class ='demo'>";

$descr1 .= "In this demo, we will apply <i>matrix-clustering</i> to a
set of motifs discovered with <i>peak-motifs</i> in ChIP-seq binding
peaks for the mouse transcription factor Otc4 (data from Chen et al.,
2008).  </p>\n";

$descr1 .= "</blockquote>";

print $query->start_multipart_form(-action=>"matrix-clustering_form.cgi");
#$demo_file = "demo_files/peak-motifs_result_Chen_Oct4_matrices.tf";
$demo_file = "demo_files/peak-motifs_Oct4_matrices.tf";
$demo_matrices=`cat ${demo_file}`;
print "<TD><b>";
print $query->hidden(-name=>'demo_descr1',-default=>$descr1);
print $query->hidden(-name=>'matrix',-default=>$demo_matrices);
#print $query->hidden(-name=>'user_email',-default=>'nobody@nowhere');
print $query->submit(-label=>"DEMO");
print "</B></TD>\n";
print $query->end_form;


print "<td><b><a href='help.compare-matrices.html'>[MANUAL]</a></B></TD>\n";
print "<TD><b><a href='http://www.bigre.ulb.ac.be/forums/' target='_top'>[ASK A QUESTION]</a></B></TD>\n";
print "</tr></table></ul></ul>\n";

print "</FONT>\n";

print $query->end_html;

exit(0);



################################################################
#################### SUBROUTINE DEFINITIONS  ###################
################################################################

