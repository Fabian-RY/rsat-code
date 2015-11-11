#!/usr/bin/perl
#### this cgi script fills the HTML form for the program retrieve-seq-bed
if ($0 =~ /([^(\/)]+)$/) {
    push (@INC, "$`lib/");
}
use CGI;
use CGI::Carp qw/fatalsToBrowser/;

require "RSA.lib";
require "RSA2.cgi.lib";
$ENV{RSA_OUTPUT_CONTEXT} = "cgi";


### Read the CGI query
$query = new CGI;

### Read the CGI query
$default{demo_descr1} = "";

### default values for filling the form
$default{organism} = "Saccharomyces cerevisiae";
$default{'bed_url'.1} = "";
$default{rm} = "";

### replace defaults by parameters from the cgi call, if defined
foreach $key (keys %default) {
  if ($query->param($key)) {
    $default{$key} = $query->param($key);
  }
}

# ## radio button checked values (to be placed after changing default values !!)
# $checked{$default{org_select}}="checked";
# $checked{$default{outputformat}}="checked";

################################################################
### print the form ###
&RSA_header("Retrieve sequences from genomic coordinates", "form");
&ListParameters() if ($ENV{rsat_echo} >= 2);

### head
print "<CENTER>";
print "Retrieve sequences for a set of genomic coordinates provided in bed,gff or vcf format.<p>";
print "Program developed by <a target='_blank' href='http://eead.csic.es/compbio/staff/bruno_contreras_moreira.html'>Bruno Contreras Moreira</a> and <a target='_blank' href='http://jacques.van-helden.perso.luminy.univ-amu.fr/'>Jacques van Helden</a>\n";
print "</CENTER>";


## demo description
print $default{demo_descr1};
print $default{demo_descr2};

print $query->start_multipart_form(-action=>"retrieve-seq-bed.cgi");


################################################################
## Field set: input genomic coordinates
print "<fieldset><legend><b><a href='help.retrieve-seq-bed.html#coordinates'>Genomic coordinates</a></b></legend>";

print "<div style='padding-left:30px'>";

## Organism choice
print "<p>";
&OrganismPopUp();
print "</p>";

## Genomic coordinates
&MultiInputChoice("Genomic coordinates",1, "coordinates", "bed/gff/vcf");
print "</div>";

print "</fieldset><p/>";
## End of genomic coordinates


#### Options
print "<fieldset>";
print "<legend><b><a href='help.retrieve-seq-bed.html'>Options</a></b></legend>";

### Repeat masking
print "<p>", $query->checkbox(-name=>'rm',
			      -checked=>$default{rm},
			      -label=>'');
print "&nbsp;<A HREF='help.retrieve-seq.html#rm'><B>Mask repeats</B></A>";
print "</p>\n";

print "</fieldset><p/>";

################################################################
## send results by email or display on the browser
print "<fieldset>";
print "<legend><b>Output</b></legend>";
print "<P>\n";
&SelectOutput("server");

## Action buttons
print "<UL><UL><TABLE class = 'formbutton'>\n";
print "<TR VALIGN=MIDDLE>\n";
print "<TD>", $query->submit(-label=>"GO"), "</TD>\n";
print "<TD>", $query->reset, "</TD>\n";
print $query->end_form;

################################################################
## data for the demo
my $demo_url= $ENV{rsat_www}."/demo_files/Arabidopsis_thaliana_GSM1482283_MYB3R3-GFP_ChIP_peaks.bed";
my $descr1="<h4>Comment on the demonstration example</h4><blockquote class ='demo'>";
$descr1 .= "The demo retrieves peak sequences from Arabidopsis thaliana, based on the coordinates of the peaks from {REF}. ";
$descr1 .= "Input coordinates are provided as the <a href='${demo_url}'>URL to a demo bed file</a>. </blockquote>";
# my $demo_file = $ENV{RSAT}."/public_html/demo_files/Arabidopsis_thaliana_GSM1482283_MYB3R3-GFP_ChIP_peaks.bed";
# my $demo_bed=`cat $demo_file`;

print $query->start_multipart_form(-action=>"retrieve-seq-bed_form.cgi");
print "<TD><B>";
$query->delete_all();
print $query->hidden(-name=>'demo_descr1',-default=>$descr1);
# print $query->hidden(-name=>'input1',-default=>$demo_bed);
print $query->hidden(-name=>'input_url1',-default=>$demo_url);
print $query->hidden(-name=>'organism',-default=>'Arabidopsis_thaliana.TAIR10.29');
print $query->hidden(-name=>'rm',-default=>'on');
print $query->submit(-label=>"DEMO");
print "</B></TD>\n";
print $query->end_form;


print "<TD><B><A HREF='help.retrieve-seq-bed.html'>MANUAL</A></B></TD>\n";
print "<TD><B><A HREF='mailto:morgane\@bigre.ulb.ac.be'>MAIL</A></B></TD>\n";
print "</TR></TABLE></UL></UL>\n";

print "</fieldset><p/>";



print $query->end_html;

exit(0);

