############################################################
## RSATWS.pm - rsa-tools web services module

package RSATWS;

use SOAP::Lite;
use SOAP::WSDL;

use IPC::Open3;

use vars qw(@ISA);
@ISA = qw(SOAP::Server::Parameters);

use File::Temp qw/ tempfile tempdir /;

unshift (@INC, "../../perl-scripts/lib/");

require RSAT::util;
require RSAT::server;
require RSAT::TaskManager;

&main::InitRSAT();


#my $RSAT = $0; $RSAT =~ s|/public_html/+web_services/.*||;
my $RSAT = $ENV{RSAT};
unless ($RSAT) {
    $RSAT = $0; $RSAT =~ s|/public_html/+web_services/.*||; ## Guess RSAT path from module full name
#    $RSAT = join(";","ENV", keys(%ENV));
}
my $SCRIPTS = $RSAT.'/perl-scripts';
my $TMP = $RSAT.'/public_html/tmp';


#require "RSA.lib";

=pod

=head1 NAME

    RSAT::RSATWS

=head1 DESCRIPTION

Documentation for this module is at http://rsat.scmbb.ulb.ac.be/rsat/web_services/RSATWS_documentation.xml

=cut

##########
sub retrieve_seq {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  my $organism = $args{"organism"};
  my $noorf = $args{"noorf"};
  my $from = $args{"from"};
  my $to = $args{"to"};

  ## List of query genes
  my $query_ref = $args{"query"};
  my $query = "";
  if ($query_ref =~ /ARRAY/) {
      my @query = @{$query_ref};
      foreach $q (@query) {
	  $q =~s/\'//g;
	  $q =~s/\"//g;
      }
      $query = " -q '";
      $query .= join "' -q '", @query;
      $query .= "'";
  } elsif ($query_ref) {
      $query = " -q '";
      $query .= $query_ref;
      $query .= "'";
  }

  my $feattype = $args{"feattype"};
  my $type = $args{"type"};
  my $format = $args{"format"};
  my $all = $args{"all"};
  my $lw = $args{"lw"};
  my $label = $args{"label"};
  my $label_sep = $args{"label_sep"};
  my $nocom = $args{"nocom"};
  my $repeat = $args{'repeat'};
  my $imp_pos = $args{'imp_pos'};

  my $command = "$SCRIPTS/retrieve-seq";

  if ($organism) {
    $organism =~ s/\'//g;
    $organism =~ s/\"//g;
    $command .= " -org '".$organism."'";
  }

  if ($query) {
    $command .= $query;
  }

  if ($noorf == 1) {
    $command .= " -noorf";
  }

  if ($from =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $from =~ s/\'//g;
    $from =~ s/\"//g;
    $command .= " -from '".$from."'";
  }

  if ($to =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $to =~ s/\'//g;
    $to =~ s/\"//g;
    $command .= " -to '".$to."'";
  }

  if ($feattype) {
    $feattype =~ s/\'//g;
    $feattype =~ s/\"//g;
    $command .= " -feattype '".$feattype."'";
  }

  if ($type) {
    $type =~ s/\'//g;
    $type =~ s/\"//g;
    $command .= " -type '".$type."'";
  }

  if ($format) {
      $format =~ s/\'//g;
      $format =~ s/\"//g;
      $command .= " -format '".$format."'";
  } else {
      $format = ".fasta";
  }

  if ($all == 1) {
    $command .= " -all";
  }

  if ($lw) {
    $lw =~ s/\'//g;
    $lw =~ s/\"//g;
    $command .= " -lw '".$lw."'";
  }

  if ($label) {
    $label =~ s/\'//g;
    $label =~ s/\"//g;
    $command .= " -label '".$label."'";
  }

  if ($label_sep) {
    $label_sep =~ s/\'//g;
    $label_sep =~ s/\"//g;
    $command .= " -labelsep '".$label_sep."'";
  }

  if ($nocom == 1) {
    $command .= " -nocom";
  }

  if ($repeat == 1) {
    $command .= " -rm";
  }

  if ($imp_pos == 1) {
    $command .= " -imp_pos";
  }

  &run_WS_command($command, $output_choice, "retrieve-seq", $format);
}

##########
sub retrieve_seq_multigenome {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  my $noorf = $args{"noorf"};
  my $from = $args{"from"};
  my $to = $args{"to"};

  if ($args{"input"}) {
    my $input = $args{"input"};
    chomp $input;
    $tmp_input_file = `mktemp $TMP/retrieve-seq-multigenome.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_input_file or die "cannot open temp file ".$tmp_input_file."\n";
    print TMP_IN $input;
    close TMP_IN;
  } elsif ($args{"tmp_input_file"}) {
    $tmp_input_file = $args{"tmp_input_file"};
    $tmp_input_file =~ s/\'//g;
    $tmp_input_file =~ s/\"//g;
  }
  chomp $tmp_input_file;

  my $feattype = $args{"feattype"};
  my $type = $args{"type"};
  my $format = $args{"format"};
  my $all = $args{"all"};
  my $lw = $args{"lw"};
  my $label = $args{"label"};
  my $label_sep = $args{"label_sep"};
  my $nocom = $args{"nocom"};
  my $repeat = $args{'repeat'};
  my $imp_pos = $args{'imp_pos'};
  my $gene_col = $args{'gene_col'};
  my $org_col = $args{'org_col'};

  my $command = "$SCRIPTS/retrieve-seq-multigenome";

  if ($tmp_input_file) {
    $command .= " -i '".$tmp_input_file."'";
  }

  if ($gene_col) {
      $gene_col =~ s/\'//g;
      $gene_col =~ s/\"//g;
      $command .= " -gene_col '".$gene_col."'";
  }

  if ($org_col) {
      $org_col =~ s/\'//g;
      $org_col =~ s/\"//g;
      $command .= " -org_col '".$org_col."'";
  }

  if ($noorf == 1) {
    $command .= " -noorf";
  }

  if ($from =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $from =~ s/\'//g;
    $from =~ s/\"//g;
    $command .= " -from '".$from."'";
  }

  if ($to =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $to =~ s/\'//g;
    $to =~ s/\"//g;
    $command .= " -to '".$to."'";
  }

  if ($feattype) {
    $feattype =~ s/\'//g;
    $feattype =~ s/\"//g;
    $command .= " -feattype '".$feattype."'";
  }

  if ($type) {
    $type =~ s/\'//g;
    $type =~ s/\"//g;
    $command .= " -type '".$type."'";
  }

  if ($format) {
    $format =~ s/\'//g;
    $format =~ s/\"//g;
    $command .= " -format '".$format."'";
  }

  if ($all == 1) {
    $command .= " -all";
  }

  if ($lw) {
    $lw =~ s/\'//g;
    $lw =~ s/\"//g;
    $command .= " -lw '".$lw."'";
  }

  if ($label) {
    $label =~ s/\'//g;
    $label =~ s/\"//g;
    $command .= " -label '".$label."'";
  }

  if ($label_sep) {
    $label_sep =~ s/\'//g;
    $label_sep =~ s/\"//g;
    $command .= " -labelsep '".$label_sep."'";
  }

  if ($nocom == 1) {
    $command .= " -nocom";
  }

  if ($repeat == 1) {
    $command .= " -rm";
  }

  if ($imp_pos == 1) {
    $command .= " -imp_pos";
  }

  &run_WS_command($command, $output_choice, "retrieve-seq-multigenome");
}

##########
sub retrieve_ensembl_seq {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }

  my $organism = $args{"organism"};
  my $ensembl_host = $args{"ensembl_host"};
  my $dbname = $args{"db_name"};
  my $noorf = $args{"noorf"};
  my $nogene = $args{"nogene"};
  my $from = $args{"from"};
  my $to = $args{"to"};

  ## List of query genes
  my $query_ref = $args{"query"};
  my $query = "";
  if ($query_ref =~/ARRAY/) {
      my @query = @{$query_ref};
      foreach $q (@query) {
	  $q =~s/\'//g;
	  $q =~s/\"//g;
      }
      $query = " -q '";
      $query .= join "' -q '", @query;
      $query .= "'";
  } elsif ($query_ref) {
      $query = " -q '";;
      $query .= $query_ref;
      $query .= "'";
  }

  if ($args{"tmp_infile"}) {
      $tmp_infile = $args{"tmp_infile"};
      $tmp_infile =~ s/\'//g;
      $tmp_infile =~ s/\"//g;
      chomp $tmp_infile;
  }

  my $feattype = $args{"feattype"};
  my $type = $args{"type"};
# my $format = $args{"format"};
  my $all = $args{"all"};
  my $lw = $args{"line_width"};
# my $label = $args{"label"};
# my $label_sep = $args{"label_sep"};
# my $nocom = $args{"nocom"};
  my $repeat = $args{'repeat'};
  my $mask_coding = $args{"mask_coding"};
  my $all_transcripts = $args{"all_transcripts"};
  my $uniqseqs = $args{"unique_sequences"};
  my $first_intron = $args{"first_intron"};
  my $non_coding = $args{"non_coding"};
  my $utr = $args{"utr"};
  my $chrom = $args{"chromosome"};
  my $left = $args{"left"};
  my $right =$args{"right"};
  my $strand = $args{"strand"};
  my $ortho = $args{"ortho"};
  my $taxon = $args{"taxon"};
  my $homology_type = $args{"homology_type"};
  my $header_org = $args{"header_organism"};

  if ($args{"features"}) {
    my $features = $args{"features"};
    chomp $features;
    $tmp_ft_file = `mktemp $TMP/retrieve-ensembl-seq.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_ft_infile or die "cannot open temp file ".$tmp_ft_infile."\n";
    print TMP_IN $feature;
    close TMP_IN;
  } elsif ($args{"tmp_ft_file"}) {
    $tmp_ft_file = $args{"tmp_ft_file"};
    $tmp_ft_file =~ s/\'//g;
    $tmp_ft_file =~ s/\"//g;
  }

  my $feat_format = $args{"feat_format"};
# my $imp_pos = $args{'imp_pos'};

  my $command = "$SCRIPTS/retrieve-ensembl-seq.pl";

  if ($organism) {
    $organism =~ s/\'//g;
    $organism =~ s/\"//g;
    $command .= " -org '".$organism."'";
  }

  if ($ensembl_host) {
    $ensembl_host =~ s/\'//g;
    $ensembl_host =~ s/\"//g;
    $command .= " -ensemblhost '".$ensembl_host."'";
  }

  if ($dbname) {
    $dbname =~ s/\'//g;
    $dbname =~ s/\"//g;
    $command .= " -dbname '".$dbname."'";
  }

  if ($query) {
    $command .= $query;
  }

  if ($noorf == 1) {
    $command .= " -noorf";
  }

  if ($nogene == 1) {
    $command .= " -nogene";
  }

  if ($from =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $from =~ s/\'//g;
    $from =~ s/\"//g;
    $command .= " -from '".$from."'";
  }

  if ($to =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $to =~ s/\'//g;
    $to =~ s/\"//g;
    $command .= " -to '".$to."'";
  }

  if ($feattype) {
    $feattype =~ s/\'//g;
    $feattype =~ s/\"//g;
    $command .= " -feattype '".$feattype."'";
  }

  if ($type) {
    $type =~ s/\'//g;
    $type =~ s/\"//g;
    $command .= " -type '".$type."'";
  }

  if ($format) {
    $format =~ s/\'//g;
    $format =~ s/\"//g;
    $command .= " -format '".$format."'";
  }

  if ($all == 1) {
    $command .= " -all";
  }

  if ($lw) {
      $lw =~ s/\'//g;
      $lw =~ s/\"//g;
      $command .= " -lw '".$lw."'";
  }

#    if ($label) {
#	$label =~ s/\'//g;
#	$label =~ s/\"//g;
#	$command .= " -label '".$label."'";
#    }

#    if ($label_sep) {
#	$label_sep =~ s/\'//g;
#	$label_sep =~ s/\"//g;
#	$command .= " -labelsep '".$label_sep."'";
#    }

#    if ($nocom == 1) {
#	$command .= " -nocom";
#    }

    if ($repeat == 1) {
	$command .= " -rm";
    }

   if ($mask_coding == 1) {
	$command .= " -maskcoding";
    }

   if ($all_transcripts == 1) {
	$command .= " -alltranscripts";
    }

   if ($uniqseqs == 1) {
	$command .= " -uniqseqs";
    }


   if ($first_intron == 1) {
	$command .= " -firstintron";
    }

   if ($non_coding == 1) {
	$command .= " -noncoding";
    }

  if ($utr) {
      $utr =~ s/\'//g;
      $utr =~ s/\"//g;
      $command .= " -utr '".$utr."'";
  }

    if ($chrom) {
	$chrom =~ s/\'//g;
	$chrom =~ s/\"//g;
	$command .= " -chrom '".$chrom."'";
    }

    if ($left) {
	$left =~ s/\'//g;
	$left =~ s/\"//g;
	$command .= " -left '".$left."'";
    }

    if ($right) {
	$right =~ s/\'//g;
	$right =~ s/\"//g;
	$command .= " -right '".$right."'";
    }

    if ($strand) {
	$strand =~ s/\'//g;
	$strand =~ s/\"//g;
	$command .= " -strand '".$strand."'";
    }

    if ($features) {
	$features =~ s/\'//g;
	$features =~ s/\"//g;
	$command .= " -ftfile '".$tmp_ft_file."'";
    }

    if ($feat_format) {
	$feat_format =~ s/\'//g;
	$feat_format =~ s/\"//g;
	$command .= " -ftfileformat '".$feat_format."'";
    }

   if ($ortho == 1) {
	$command .= " -ortho";
    }

    if ($taxon) {
	$taxon =~ s/\'//g;
	$taxon =~ s/\"//g;
	$command .= " -taxon '".$taxon."'";
    }

    if ($homology_type) {
	$homology_type =~ s/\'//g;
	$homology_type =~ s/\"//g;
	$command .= " -ortho_type '".$homology_type."'";
    }

    if ($header_org) {
	$header_org =~ s/\'//g;
	$header_org =~ s/\"//g;
	$command .= " -header_org '".$header_org."'";
    }

#    if ($imp_pos == 1) {
#	$command .= " -imp_pos";
#    }

  if ($args{"tmp_infile"}) {
      $command .= " -i '".$tmp_infile."'";
  }

 &run_WS_command($command, $output_choice, "retrieve-ensembl-seq")
}

##########
sub purge_seq {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    if ($args{"sequence"}) {
	my $sequence = $args{"sequence"};
	chomp $sequence;
	$tmp_infile = `mktemp $TMP/purge-sequence.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $sequence;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
	$tmp_infile =~ s/\'//g;
	$tmp_infile =~ s/\"//g;
    }
    chomp $tmp_infile;
    my $format = $args{"format"};
    my $match_length = $args{"match_length"};
    my $mismatch = $args{"mismatch"};
    my $str = $args{"str"};
    my $delete = $args{"delete"};
    my $mask_short = $args{"mask_short"};

    my $command = "$SCRIPTS/purge-sequence";

    if ($format) {
      $format =~ s/\'//g;
      $format =~ s/\"//g;
      $command .= " -format '".$format."'";
  } else {
      $format = ".fasta";
  }

    if ($str =~ /\d/) {
	if ($str == 1 || $str == 2) {
	    $command .= " -".$str."str";
	} else {
	    die "str value must be 1 or 2";
	}
    }

    if ($delete == 1) {
      $command .= " -del";
    }

    if ($mask_short) {
      $mask_short =~ s/\'//g;
      $mask_short =~ s/\"//g;
      $command .= " -mask_short '".$mask_short."'";
    }

    if ($match_length) {
	$match_length =~ s/\'//g;
	$match_length =~ s/\"//g;
	$command .= " -ml '".$match_length."'";
    }

    if ($mismatch) {
	$mismatch =~ s/\'//g;
	$mismatch =~ s/\"//g;
	$command .= " -mis '".$mismatch."'";
    }

    $command .= " -i '".$tmp_infile."'";

    &run_WS_command($command, $output_choice, "purge-sequence", $format);
}

##########
sub oligo_analysis {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    if ($args{"sequence"}) {
	my $sequence = $args{"sequence"};
	chomp $sequence;
	$tmp_infile = `mktemp $TMP/oligo.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $sequence;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
    }
    chomp $tmp_infile;
    my $verbosity = $args{'verbosity'};
    my $format = $args{"format"};
    my $length = $args{"length"};
    my $organism = $args{"organism"};
    my $background = $args{"background"};
    my $stats = $args{"stats"};
    my $noov = $args{"noov"};
    my $str = $args{"str"};
    my $sort = $args{"sort"};

    ## List of lower thresholds
    my $lth_ref = $args{"lth"};
    my $lth = "";
    if ($lth_ref =~ /ARRAY/) {
#      my %lth = %{$lth_ref};
#      foreach $lt (keys %lth) {
#	$lt =~s/\'//g;
#	$lt =~s/\"//g;
#	$value = $lth{$lt};
#	$value =~s/\'//g;
#	$value =~s/\"//g;
#	$lthreshold .= " -lth ".$lt." ".$value;
#      }
      my @lth = @{$lth_ref};
      foreach $lt (@lth) {
	$lt =~s/\'//g;
	$lt =~s/\"//g;
	@_lt = split / /, $lt;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
      }
    } elsif ($lth_ref) {
	@_lt = split / /, $lth_ref;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
    }

    ## List of upper thresholds
    my $uth_ref = $args{"uth"};
    my $uth = "";
    if ($uth_ref =~ /ARRAY/) {
      my @uth = @{$uth_ref};
      foreach $ut (@uth) {
	$ut =~s/\'//g;
	$ut =~s/\"//g;
	@_ut = split / /, $ut;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
      }
    } elsif ($uth_ref) {
	@_ut = split / /, $uth_ref;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
    }

    my $pseudo = $args{'pseudo'};

    my $command = "$SCRIPTS/oligo-analysis";

    if ($verbosity) {
      $verbosity =~ s/\'//g;
      $verbosity =~ s/\"//g;
      $command .= " -v '".$verbosity."'";
    }

    if ($format) {
      $format =~ s/\'//g;
      $format =~ s/\"//g;
      $command .= " -format '".$format."'";
    }

    if ($organism) {
      $organism =~ s/\'//g;
      $organism =~ s/\"//g;
      $command .= " -org '".$organism."'";
    }

    if ($background) {
      $background =~ s/\'//g;
      $background =~ s/\"//g;
      $command .= " -bg '".$background."'";
    }

    if ($stats) {
      $stats =~ s/\'//g;
      $stats =~ s/\"//g;
      $command .= " -return '".$stats."'";
    }

    if ($noov == 1) {
      $command .= " -noov";
    }

    if ($str =~ /\d/) {
	if ($str == 1 || $str == 2) {
	    $command .= " -".$str."str";
	} else {
	    die "str value must be 1 or 2";
	}
    }

    if ($sort == 1) {
      $command .= " -sort";
    }

    if ($lth) {
      $command .= $lth;
    }

    if ($uth) {
      $command .= $uth;
    }

    if ($pseudo =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
	$pseudo =~ s/\'//g;
	$pseudo =~ s/\"//g;
	$command .= " -pseudo '".$pseudo."'";
    }

    if ($length) {
	$length =~ s/\'//g;
	$length =~ s/\"//g;
	$command .= " -l '".$length."'";
    }

    $command .= " -i '".$tmp_infile."'";

    &run_WS_command($command, $output_choice, "oligo-analysis", ".tab");
}

##########
sub dyad_analysis {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    if ($args{"sequence"}) {
	my $sequence = $args{"sequence"};
	chomp $sequence;
	$tmp_infile = `mktemp $TMP/dyad.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $sequence;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
    }
    chomp $tmp_infile;
    my $format = $args{"format"};
    my $length = $args{"length"};
    my $spacing = $args{"spacing"};
    my $type = $args{"type"};
    my $organism = $args{"organism"};
    my $background = $args{"background"};
    my $stats = $args{"stats"};
    my $noov = $args{"noov"};
    my $str = $args{"str"};
    my $sort = $args{"sort"};
    my $under = $args{"under"};
    my $two_tails = $args{"two_tails"};
    my $zeroocc = $args{"zeroocc"};

    ## List of lower thresholds
    my $lth_ref = $args{"lth"};
    my $lth = "";
    if ($lth_ref =~ /ARRAY/) {
      my @lth = @{$lth_ref};
      foreach $lt (@lth) {
	$lt =~s/\'//g;
	$lt =~s/\"//g;
	@_lt = split / /, $lt;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
      }
    } elsif ($lth_ref) {
	@_lt = split / /, $lth_ref;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
    }

    ## List of upper thresholds
    my $uth_ref = $args{"uth"};
    my $uth = "";
    if ($uth_ref =~ /ARRAY/) {
      my @uth = @{$uth_ref};
      foreach $ut (@uth) {
	$ut =~s/\'//g;
	$ut =~s/\"//g;
	@_ut = split / /, $ut;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
      }
    } elsif ($uth_ref) {
	@_ut = split / /, $uth_ref;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
    }

    my $command = "$SCRIPTS/dyad-analysis";

    if ($format) {
      $format =~ s/\'//g;
      $format =~ s/\"//g;
      $command .= " -format '".$format."'";
    }

    if ($organism) {
      $organism =~ s/\'//g;
      $organism =~ s/\"//g;
      $command .= " -org '".$organism."'";
    }

    if ($background) {
      $background =~ s/\'//g;
      $background =~ s/\"//g;
      $command .= " -bg '".$background."'";
    }

    if ($stats) {
      $stats =~ s/\'//g;
      $stats =~ s/\"//g;
      $command .= " -return '".$stats."'";
    }

    if ($noov == 1) {
      $command .= " -noov";
    }

    if ($str =~ /\d/) {
	if ($str == 1 || $str == 2) {
	    $command .= " -".$str."str";
	} else {
	    die "str value must be 1 or 2";
	}
    }

    if ($sort == 1) {
      $command .= " -sort";
    }

    if ($lth) {
      $command .= $lth;
    }

    if ($uth) {
      $command .= $uth;
    }

    if ($length) {
	$length =~ s/\'//g;
	$length =~ s/\"//g;
	$command .= " -l '".$length."'";
    }

    if ($spacing) {
	$spacing =~ s/\'//g;
	$spacing =~ s/\"//g;
	$command .= " -sp '".$spacing."'";
    }

    if ($type) {
	$type =~ s/\'//g;
	$type =~ s/\"//g;
	$command .= " -type '".$type."'";
    }

    if ($under == 1) {
      $command .= " -under";
    }

    if ($two_tails == 1) {
      $command .= " -two_tails";
    }

    if ($zeroocc == 1) {
      $command .= " -zeroocc";
    }

    $command .= " -i '".$tmp_infile."'";

    &run_WS_command($command, $output_choice, "dyad-analysis", ".tab");
}

##########
sub pattern_assembly {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
      $output_choice = 'both';
    }
  my $command = "$SCRIPTS/pattern-assembly";

  ## Input file
  if ($args{"input"}) {
    my $input = $args{"input"};
    chomp $input;
    $tmp_infile = `mktemp $TMP/pattern-assembly.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
    print TMP_IN $input;
    close TMP_IN;
  } elsif ($args{"tmp_infile"}) {
    $tmp_infile = $args{"tmp_infile"};
  }
  chomp $tmp_infile;
  $command .= " -i '".$tmp_infile."'";

  ## Verbosity
  my $v = $args{"verbosity"};
  if ($v =~ /^\d+$/) {
    $command .= " -v ".$v;
  }

  ## Strands
  my $str = $args{"str"};
  if ($str =~ /\d/) {
    if ($str == 1 || $str == 2) {
      $command .= " -".$str."str";
    } else {
      die "str value must be 1 or 2";
    }
  }

  ## Score column
  my $score_col = $args{score_col};
  if ($score_col =~ /^\d+$/) {
#  if (&IsNatural($score_col)) {
    $command .= " -sc ".$score_col;
  }

  ## Max flanking segment size
  my $maxfl = $args{maxfl};
  if ($maxfl =~ /^\d+$/) {
#  if (&IsNatural($maxfl)) {
    $command .= " -maxfl ".$maxfl;
  }

  ## Max substitutions
  my $subst = $args{subst};
  if ($subst =~ /^\d+$/) {
#  if (&IsNatural($subst)) {
    $command .= " -subst ".$subst;
  }

  ## Max assembly size (number of patterns per cluster)
  my $maxcl = $args{maxcl};
  if ($maxcl =~ /^\d+$/) {
#  if (&IsNatural($maxcl)) {
    $command .= " -maxcl ".$maxcl;
  }

  ## Max number of patterns in total
  my $maxpat = $args{maxpat};
  if ($maxpat =~ /^\d+$/) {
#  if (&IsNatural($maxpat)) {
    $command .= " -maxpat ".$maxpat;
  }

  ## Max number of top patterns to use for assembly
  my $toppat = $args{toppat};
  if ($toppat =~ /^\d+$/) {
#  if (&IsNatural($toppat)) {
    $command .= " -toppat ".$toppat;
  }

    &run_WS_command($command, $output_choice, "pattern-assembly");
}

##########
sub dna_pattern {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    if ($args{"sequence"}) {
	my $sequence = $args{"sequence"};
	chomp $sequence;
	$tmp_infile = `mktemp $TMP/dna_pattern.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $sequence;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
    }
    chomp $tmp_infile;

    my $tmp_pattern_file;
    if ($args{"pattern_file"}) {
	my $patterns = $args{"pattern_file"};
	chomp $patterns;
	$tmp_pattern_file = `mktemp $TMP/dnapatt-pattern_file.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_pattern_file or die "cannot open temp file ".$tmp_pattern_file."\n";
	print TMP_IN $patterns;
	close TMP_IN;
    } elsif ($args{"tmp_pattern_file"}){
	$tmp_pattern_file = $args{"tmp_pattern_file"};
    }

    my $format = $args{"format"};
    my $pattern = $args{"pattern"};
    my $subst = $args{"subst"};
    my $id = $args{"id"};
    my $origin = $args{"origin"};
    my $noov = $args{"noov"};
    my $str = $args{"str"};
    my $sort = $args{"sort"};
    my $th = $args{"th"};
    my $score = $args{'score'};
    my $return = $args{'return'};

    my $command = "$SCRIPTS/dna-pattern";

    if ($format) {
      $format =~ s/\'//g;
      $format =~ s/\"//g;
      $command .= " -format '".$format."'";
    }

    if ($pattern) {
      chomp $pattern;
      $pattern =~ s/\'//g;
      $pattern =~ s/\"//g;
      $command .= " -p '".$pattern."'";
    }

    if ($tmp_pattern_file) {
      chomp $tmp_pattern_file;
      $tmp_pattern_file =~ s/\'//g;
      $tmp_pattern_file =~ s/\"//g;
      $command .= " -pl '".$tmp_pattern_file."'";
    }

    if ($subst) {
      $subst =~ s/\'//g;
      $subst =~ s/\"//g;
      $command .= " -subst '".$subst."'";
    }

    if ($id) {
      $id =~ s/\'//g;
      $id =~ s/\"//g;
      $command .= " -id '".$id."'";
    }

    if ($noov == 1) {
      $command .= " -noov";
    }

    if ($str  =~ /\d/) {
	if ($str == 1 || $str == 2) {
	    $command .= " -".$str."str";
	} else {
	    die "str value must be 1 or 2";
	}
    }

    if ($sort == 1) {
      $command .= " -sort";
    }

    if ($th) {
      $th =~ s/\'//g;
      $th =~ s/\"//g;
      $command .= " -th '".$th."'";
    }

    if ($origin) {
	$origin =~ s/\'//g;
	$origin =~ s/\"//g;
	$command .= " -origin '".$origin."'";
    }

    if ($score) {
	$score =~ s/\'//g;
	$score =~ s/\"//g;
	$command .= " -sc '".$score."'";
    }

    if ($return) {
        $return =~ s/\'//g;
        $return =~ s/\"//g;
        $command .= " -return '".$return."'";
    }

    $command .= " -i '".$tmp_infile."'";

    &run_WS_command($command, $output_choice, "dna-pattern");
}

##########
sub convert_features {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
      $output_choice = 'both';
    }
    if ($args{"input"}) {
	my $input = $args{"input"};
	chomp $input;
	$tmp_infile = `mktemp $TMP/convert-features.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $input;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
    }
    chomp $tmp_infile;

    my $from = $args{"from"};
    my $to = $args{"to"};

    my $command = "$SCRIPTS/convert-features";

    if ($from) {
      $from =~ s/\'//g;
      $from =~ s/\"//g;
      $command .= " -from '".$from."'";
    }

    if ($to) {
      $to =~ s/\'//g;
      $to =~ s/\"//g;
      $command .= " -to '".$to."'";
    }

    $command .= " -i '".$tmp_infile."'";

     &run_WS_command($command, $output_choice, "convert-features");
}

##########
sub feature_map {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }

    my $suffix;
    if ($args{'format'}) {
        $suffix = ".".$args{'format'};
    } else {
        $suffix = ".jpg";
    }

#    $tmp_outfile =~ s/\/home\/rsat\/rsa-tools\/public_html/http\:\/\/rsat\.scmbb\.ulb\.ac\.be\/rsat/g;
#    $tmp_outfile =~ s/\/home\/rsat\/rsa-tools\/public_html/$ENV{rsat_www}/g;

    if ($args{"features"}) {
	my $features = $args{"features"};
	chomp $features;
	$tmp_infile = `mktemp $TMP/feature-map.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $features;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
    }
    chomp $tmp_infile;

    if ($args{"sequence"}) {
	my $sequence = $args{"sequence"};
	chomp $sequence;
	$tmp_sequence_file = `mktemp $TMP/feature-map.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_sequence_file or die "cannot open temp file ".$tmp_sequence_file."\n";
	print TMP_IN $sequence;
	close TMP_IN;
    } elsif ($args{"tmp_sequence_file"}) {
	$tmp_sequence_file = $args{"tmp_sequence_file"};
    }
    chomp $tmp_sequence_file;

    my $format = $args{"format"};
    my $from = $args{"from"};
    my $to = $args{"to"};
    my $title = $args{"title"};
    my $label = $args{"label"};
    my $symbol = $args{"symbol"};
    my $dot = $args{"dot"};
    my $mlen = $args{"mlen"};
    my $mapthick = $args{"mapthick"};
    my $mspacing = $args{"mspacing"};
    my $origin = $args{"origin"};
    my $legend = $args{"legend"};
    my $scalebar = $args{"scalebar"};
    my $scalestep = $args{"scalestep"};
    my $scorethick = $args{"scorethick"};
    my $maxscore = $args{"maxscore"};
    my $minscore = $args{"minscore"};
    my $maxfthick = $args{"maxfthick"};
    my $minfthick = $args{"minfthick"};
    my $htmap = $args{"htmap"};
    my $mono = $args{"mono"};
    my $orientation = $args{"orientation"};
    my $select = $args{"select"};
    my $sequence_format = $args{'sequence_format'};

    my $command = "$SCRIPTS/feature-map";

    if ($format) {
      $format =~ s/\'//g;
      $format =~ s/\"//g;
      $command .= " -format '".$format."'";
    }

    if ($from =~ /\d/) {
      $from =~ s/\'//g;
      $from =~ s/\"//g;
      $command .= " -from '".$from."'";
    }

    if ($to =~ /\d/) {
      $to =~ s/\'//g;
      $to =~ s/\"//g;
      $command .= " -to '".$to."'";
    }

    if ($title) {
      $title =~ s/\'//g;
      $title =~ s/\"//g;
      $command .= " -title '".$title."'";
    }

    if ($label) {
      $label =~ s/\'//g;
      $label =~ s/\"//g;
      $command .= " -label '".$label."'";
    }

    if ($symbol == 1) {
      $command .= " -symbol";
    }

    if ($dot == 1) {
      $command .= " -dot";
    }

    if ($htmap == 1) {
      $command .= " -htmap";
    }

    if ($legend == 1) {
      $command .= " -legend";
    }

    if ($scalebar == 1) {
      $command .= " -scalebar";
    }

    if ($scorethick == 1) {
      $command .= " -scorethick";
    }

    if ($orientation) {
	if ($orientation eq "horiz" || $orientation eq "vertic") {
	    $command .= " -".$orientation;
	} else {
	    die "Orientation must be equal to either 'horiz' or 'vertic'";
	}
    }

    if ($mono == 1) {
      $command .= " -mono";
    }

    if ($mlen =~ /\d/) {
      $mlen =~ s/\'//g;
      $mlen =~ s/\"//g;
      $command .= " -mlen '".$mlen."'";
    }

    if ($mapthick =~ /\d/) {
      $mapthick =~ s/\'//g;
      $mapthick =~ s/\"//g;
      $command .= " -mapthick '".$mapthick."'";
    }

    if ($mspacing =~ /\d/) {
      $mspacing =~ s/\'//g;
      $mspacing =~ s/\"//g;
      $command .= " -mspacing '".$mspacing."'";
    }

    if ($origin =~ /\d/) {
      $origin =~ s/\'//g;
      $origin =~ s/\"//g;
      $command .= " -origin '".$origin."'";
    }

    if ($scalestep =~ /\d/) {
      $scalestep =~ s/\'//g;
      $scalestep =~ s/\"//g;
      $command .= " -scalestep '".$scalestep."'";
    }

    if ($maxscore =~ /\d/) {
      $maxscore =~ s/\'//g;
      $maxscore =~ s/\"//g;
      $command .= " -maxscore '".$maxscore."'";
    }

    if ($minscore =~ /\d/) {
      $minscore =~ s/\'//g;
      $minscore =~ s/\"//g;
      $command .= " -minscore '".$minscore."'";
    }

    if ($maxfthick =~ /\d/) {
      $maxfthick =~ s/\'//g;
      $maxfthick =~ s/\"//g;
      $command .= " -maxfthick '".$maxfthick."'";
    }

    if ($minfthick =~ /\d/) {
      $minfthick =~ s/\'//g;
      $minfthick =~ s/\"//g;
      $command .= " -minfthick '".$minfthick."'";
    }

    if ($select) {
	$select =~ s/\'//g;
	$select =~ s/\"//g;
	$command .= " -select '".$select."'";
    }

    if ($tmp_sequence_file) {
	$tmp_sequence_file =~ s/\'//g;
	$tmp_sequence_file =~ s/\"//g;
	$command .= " -seq '".$tmp_sequence_file."'";
    }

    if ($sequence_format) {
      $sequence_format =~ s/\'//g;
      $sequence_format =~ s/\"//g;
      $command .= " -seqformat '".$sequence_format."'";
    }

    $command .= " -i '".$tmp_infile."'";

    &run_WS_command($command, $output_choice, "feature_map", $suffix);
}

##########
sub get_orthologs {
  my ($self, $args_ref) = @_;

  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }

    my $command = $self->get_orthologs_cmd(%args);

  local(*HIS_IN, *HIS_OUT, *HIS_ERR);
  my $childpid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $command);
  my @outlines = <HIS_OUT>;    # Read till EOF.
  my @errlines = <HIS_ERR>;    # XXX: block potential if massive

  my $result = join('', @outlines);
  my $stderr;

  foreach my $errline(@errlines) {
      ## Some errors and RSAT warnings are not considered as fatal errors
      unless (($errline =~ 'Use of uninitialized value') || ($errline =~'WARNING')) {
	  $stderr .= $errline;
      }
      ## RSAT warnings are added at the end of results
      if ($errline =~'WARNING') {
	  $result .= $errline;
      }
  }

  close HIS_OUT;
  close HIS_ERR;

#    if ($stderr) {
#        die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
#    }

    my ($TMP_OUT, $tmp_outfile) = &File::Temp::tempfile(get_orthologs.XXXXXXXXXX, DIR => $TMP);
    print $TMP_OUT $result;
    close $TMP_OUT;

    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"get-orthologs",output_choice=>$output_choice);

    if ($output_choice eq 'server') {
        return SOAP::Data->name('response' => {'command' => $command, 
                                               'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
        return SOAP::Data->name('response' => {'command' => $command,
                                               'client' => $result});
    } elsif ($output_choice eq 'both') {
        return SOAP::Data->name('response' => {'server' => $tmp_outfile,
                                               'command' => $command, 
                                               'client' => $result});
    }
}

sub get_orthologs_cmd {
  my ($self, %args) =@_;

  ## List of queries
  my $query_ref = $args{"query"};
  my $query = "";
  if ($query_ref =~ /ARRAY/) {
    my @query = @{$query_ref};
    foreach $q (@query) {
	$q =~s/\'//g;
	$q =~s/\"//g;
    }
    $query = " -q '";
    $query .= join "' -q '", @query;
    $query .= "'";
  } elsif ($query_ref) {
    $query = " -q '";;
    $query .= $query_ref;
    $query .= "'";
}

    ## List of lower thresholds
    my $lth_ref = $args{"lth"};
    my $lth = "";
    if ($lth_ref =~ /ARRAY/) {
      my @lth = @{$lth_ref};
      foreach $lt (@lth) {
	$lt =~s/\'//g;
	$lt =~s/\"//g;
	@_lt = split / /, $lt;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
      }
    } elsif ($lth_ref) {
	@_lt = split / /, $lth_ref;
        $lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
    }

    ## List of upper thresholds
    my $uth_ref = $args{"uth"};
    my $uth = "";
    if ($uth_ref =~ /ARRAY/) {
      my @uth = @{$uth_ref};
      foreach $ut (@uth) {
	$ut =~s/\'//g;
	$ut =~s/\"//g;
	@_ut = split / /, $ut;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
      }
    } elsif ($uth_ref) {
	@_ut = split / /, $uth_ref;
        $uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
}

  my $command = "$SCRIPTS/get-orthologs";

  if ($args{organism}) {
      $args{organism} =~ s/\'//g;
      $args{organism} =~ s/\"//g;
      $command .= " -org '".$args{organism}."'";
  }
  if ($args{taxon}) {
      $args{taxon} =~ s/\'//g;
      $args{taxon} =~ s/\"//g;
      $command .= " -taxon '".$args{taxon}."'";
  }
  if ($query) {
    $command .= $query;
  }
  if ($args{all} == 1) {
    $command .= " -all";
  }
  if ($args{nogrep} == 1){
    $command .= " -nogrep";
  }
  if ($args{return}) {
      $args{return} =~ s/\'//g;
      $args{return} =~ s/\"//g;
      $command .= " -return '".$args{return}."'";
  }
    if ($lth) {
      $command .= $lth;
    }

    if ($uth) {
      $command .= $uth;
    }

  return $command;
}

##########
sub footprint_discovery {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $command = $self->footprint_discovery_cmd(%args);

    local(*HIS_IN, *HIS_OUT, *HIS_ERR);
    my $childpid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $command);
    my @outlines = <HIS_OUT>;    # Read till EOF.
    my @errlines = <HIS_ERR>;    # XXX: block potential if massive

    my $result = join('', @outlines);
    my $stderr;

    foreach my $errline(@errlines) {
	## Some errors and RSAT warnings are not considered as fatal errors
	unless (($errline =~ 'Use of uninitialized value') || ($errline =~'WARNING')) {
	    $stderr .= $errline;
	}
	## RSAT warnings are added at the end of results
	if ($errline =~'WARNING') {
	    $result .= $errline;
	}
    }
    
    close HIS_OUT;
    close HIS_ERR;

#    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
    }
#    my $result = `$command`;
    my ($TMP_OUT, $tmp_outfile) = &File::Temp::tempfile(footprint_discovery.XXXXXXXXXX, DIR => $TMP);
    print $TMP_OUT $result;
    close $TMP_OUT;
    $tmp_outfile =~ s/\/home\/rsat\/rsa-tools\/public_html/http\:\/\/rsat\.scmbb\.ulb\.ac\.be\/rsat/g;
#    $tmp_outfile =~ s/\/home\/rsat\/rsa-tools\/public_html/$ENV{rsat_www}/g;

    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"footprint-discovery",output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}

sub footprint_discovery_cmd {
    my ($self, %args) =@_;
    if ($args{"genes"}) {
	my $genes = $args{"genes"};
	chomp $genes;
	$tmp_infile = `mktemp $TMP/footprint-discovery.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $genes;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
    }


    ## List of query genes
    my $query_ref = $args{"query"};
    my $query = "";
    if ($query_ref =~ /ARRAY/) {
	my @query = @{$query_ref};
	foreach $q (@query) {
	    $q =~s/\'//g;
	    $q =~s/\"//g;
	}
	$query = " -q '";
	$query .= join "' -q '", @query;
	$query .= "'";
    } elsif ($query_ref) {
    $query = " -q '";;
    $query .= $query_ref;
    $query .= "'";
}


    my $verbosity = $args{"verbosity"};
    my $all_genes = $args{"all_genes"};
    my $max_genes = $args{"max_genes"};
    my $output_prefix = $args{"output_prefix"};
    my $sep_genes = $args{"sep_genes"};
    my $organism = $args{"organism"};
    my $taxon = $args{"taxon"};
    my $index = $args{"index"};
    my $stats = $args{"stats"};
    my $to_matrix = $args{"to_matrix"};
    my $bg_model = $args{"bg_model"};
    my $no_filter = $args{"no_filter"};
    my $infer_operons = $args{"infer_operons"};
    my $dist_thr = $args{"dist_thr"};

    ## List of lower thresholds
    my $lth_ref = $args{"lth"};
    my $lth = "";
    if ($lth_ref =~ /ARRAY/) {
      my @lth = @{$lth_ref};
      foreach $lt (@lth) {
	$lt =~s/\'//g;
	$lt =~s/\"//g;
	@_lt = split / /, $lt;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
      }
    } elsif ($lth_ref) {
	@_lt = split / /, $lth_ref;
        $lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
    }

    ## List of upper thresholds
    my $uth_ref = $args{"uth"};
    my $uth = "";
    if ($uth_ref =~ /ARRAY/) {
      my @uth = @{$uth_ref};
      foreach $ut (@uth) {
	$ut =~s/\'//g;
	$ut =~s/\"//g;
	@_ut = split / /, $ut;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
      }
    } else {
	@_ut = split / /, $uth_ref;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
    }

    my $command = "$SCRIPTS/footprint-discovery";

    if ($verbosity) {
      $verbosity =~ s/\'//g;
      $verbosity =~ s/\"//g;
      $command .= " -v '".$verbosity."'";
    }

    if ($all_genes == 1) {
      $command .= " -all_genes";
    }

    if ($max_genes =~ /\d/) {
      $max_genes =~ s/\'//g;
      $max_genes =~ s/\"//g;
      $command .= " -max_genes '".$max_genes."'";
    }

    if ($output_prefix) {
      $output_prefix =~ s/\'//g;
      $output_prefix =~ s/\"//g;
      $command .= " -o ../tmp/'".$output_prefix."'";
  } else {
      $output_prefix = "footprints/".$taxon."/".$organism."/".$query."/".$bg_model;
      $command .= " -o ../tmp/'".$output_prefix."'";
  }

    if ($query) {
	$command .= $query;
    }

    if ($sep_genes == 1) {
      $command .= " -sep_genes";
    }

    if ($organism) {
      $organism =~ s/\'//g;
      $organism =~ s/\"//g;
      $command .= " -org '".$organism."'";
    }


    if ($taxon) {
      $taxon =~ s/\'//g;
      $taxon =~ s/\"//g;
      $command .= " -taxon '".$taxon."'";
    }

    if ($index == 1) {
      $command .= " -index";
    }

    if ($lth) {
      $command .= $lth;
    }

    if ($uth) {
      $command .= $uth;
    }

    if ($stats) {
      $stats =~ s/\'//g;
      $stats =~ s/\"//g;
      $command .= " -return '".$stats."'";
    }

    if ($to_matrix == 1) {
      $command .= " -to_matrix";
    }

    if ($bg_model) {
	if ($bg_model eq "taxfreq" || $bg_model eq "monads") {
	    $command .= " -bg_model ".$bg_model;
	} else {
	    die "Orientation must be equal to either 'taxfreq' or 'monad'";
	}
    }

    if ($no_filter == 1) {
      $command .= " -no_filter";
    }

    if ($infer_operons == 1) {
      $command .= " -infer_operons";
    }

    if ($dist_thr =~ /\d/) {
      $dist_thr =~ s/\'//g;
      $dist_thr =~ s/\"//g;
      $command .= " -dist_thr '".$dist_thr."'";
    }

    if ($tmp_infile) {
	chomp $tmp_infile;
	$command .= " -i '".$tmp_infile."'";
    }

    return $command;
}

##########
sub infer_operon {
    my ($self, $args_ref) = @_;

    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }

  ## List of queries
  my $query_ref = $args{"query"};
  my $query = "";
  if ($query_ref =~ /ARRAY/) {
    my @query = @{$query_ref};
    foreach $q (@query) {
	$q =~s/\'//g;
	$q =~s/\"//g;
    }
    $query = " -q '";
    $query .= join "' -q '", @query;
    $query .= "'";
  } elsif ($query_ref) {
    $query = " -q '";;
    $query .= $query_ref;
    $query .= "'";
  }

  my $command = "$SCRIPTS/infer-operon";

    if ($args{verbosity}) {
      $args{verbosity} =~ s/\'//g;
      $args{verbosity} =~ s/\"//g;
      $command .= " -v '".$args{verbosity}."'";
    }

  if ($args{organism}) {
      $args{organism} =~ s/\'//g;
      $args{organism} =~ s/\"//g;
      $command .= " -org '".$args{organism}."'";
  }
  if ($query) {
    $command .= $query;
  }
  if ($args{all} == 1) {
    $command .= " -all";
  }
  if ($args{distance} =~ /\d/){
      $args{distance} =~ s/\'//g;
      $args{distance} =~ s/\"//g;
    $command .= " -dist '".$args{distance}."'";
  }
  if ($args{return}) {
      $args{return} =~ s/\'//g;
      $args{return} =~ s/\"//g;
      $command .= " -return '".$args{return}."'";
  }
  if ($args{"tmp_infile"}) {
    $tmp_infile = $args{"tmp_infile"};
    $tmp_infile =~ s/\'//g;
    $tmp_infile =~ s/\"//g;
    chomp $tmp_infile;
    $command .= " -i '".$tmp_infile."'";
  }

    &run_WS_command($command, $output_choice, "infer-operon", ".tab");
}

##########
sub gene_info {
    my ($self, $args_ref) = @_;

    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }

  ## List of queries
  my $query_ref = $args{"query"};
  my $query = "";
  if ($query_ref =~ /ARRAY/) {
    my @query = @{$query_ref};
    foreach $q (@query) {
	$q =~s/\'//g;
	$q =~s/\"//g;
    }
    $query = " -q '";
    $query .= join "' -q '", @query;
    $query .= "'";
  } elsif ($query_ref) {
    $query = " -q '";;
    $query .= $query_ref;
    $query .= "'";
  }

  my $command = "$SCRIPTS/gene-info";

  if ($args{organism}) {
      $args{organism} =~ s/\'//g;
      $args{organism} =~ s/\"//g;
      $command .= " -org '".$args{organism}."'";
  }
  if ($query) {
    $command .= $query;
  }
  if ($args{full} == 1) {
    $command .= " -full";
  }
  if ($args{noquery} == 1){
    $command .= " -noquery";
  }
  if ($args{descr} == 1) {
    $command .= " -descr";
  }
  if ($args{feattype}) {
      $args{feattype} =~ s/\'//g;
      $args{feattype} =~ s/\"//g;
      $command .= " -feattype '".$args{feattype}."'";
  }

    &run_WS_command($command, $output_choice, "gene-info", ".tab");
}

##########
sub supported_organisms {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }

  my $command = "$SCRIPTS/supported-organisms";

  if ($args{format}) {
    $args{format} =~ s/\'//g;
    $args{format} =~ s/\"//g;
    $command .= " -format '".$args{format}."'";
  }
  if ($args{taxon}) {
    $args{taxon} =~ s/\'//g;
    $args{taxon} =~ s/\"//g;
    $command .= " -taxon '".$args{taxon}."'";
  }

  &run_WS_command($command, $output_choice, "supported-organisms");
}

##########
sub text_to_html {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  my $command = "$SCRIPTS/text-to-html";
  if ($args{inputfile}) {
   my $input_file = $args{inputfile};
   chomp $input_file;
   my $tmp_input = `mktemp $TMP/text-to-html-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open input temp file ".$tmp_input."\n";
   print TMP_IN $input_file;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{chunk}) {
      $args{chunk} =~ s/\'//g;
      $args{chunk} =~ s/\"//g;
      $command .= " -chunk '".$args{chunk}."'";
  }
  if ($args{font}) {
      $args{font} =~ s/\'//g;
      $args{font} =~ s/\"//g;
      $command .= " -font '".$args{font}."'";
  }
  if ($args{no_sort}) {
      $command .= " -no_sort";
  }
  
  
  &run_WS_command($command, $output_choice, "text-to-html", ".html");
}


##########

sub roc_stats{
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }

  my $command = "$SCRIPTS/roc-stats2";

  if ($args{inputfile}) {
   my $input_file = $args{inputfile};
   chomp $input_file;
   my $tmp_input = `mktemp $TMP/roc-stats-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_file;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{scol}) {
      $args{scol} =~ s/\'//g;
      $args{scol} =~ s/\"//g;
      $command .= " -scol '".$args{scol}."'";
  }
  if ($args{lcol}) {
      $args{lcol} =~ s/\'//g;
      $args{lcol} =~ s/\"//g;
      $command .= " -lcol '".$args{lcol}."'";
  }
  if ($args{status}) {
      $args{status} =~ s/\'//g;
      $args{status} =~ s/\"//g;
      $status = $args{status};
      my @statuscp = split (/ /, $status);
      if (scalar(@statuscp) % 2 ==0) {
        for (my $i = 0; $i < scalar(@statuscp)-1; $i+=2) {
          $command .= " -status '".$statuscp[$i]." ".$statuscp[$i+1]."'";
        }
      }
  }
  if ($args{total}) {
      $command .= " -total";
  }
  &run_WS_command($command, $output_choice, "roc-stats", ".tab");
}

##########
sub classfreq {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
  
  my $command = "$SCRIPTS/classfreq -v 1";
  
  if ($args{col}) {
   my $col = $args{col};
   $col =~ s/\'//g;
   $col =~ s/\'//g;
   $command .= " -col $col";
  }
  if ($args{from}) {
   my $from = $args{from};
   $from =~ s/\'//g;
   $from =~ s/\'//g;
   $command .= " -from $from";
  }
  if ($args{to}) {
   my $to = $args{to};
   $to =~ s/\'//g;
   $to =~ s/\'//g;
   $command .= " -to $to";
  }
  if ($args{min}) {
   my $min = $args{min};
   $min =~ s/\'//g;
   $min =~ s/\'//g;
   $command .= " -min $min";
  }
  if ($args{max}) {
   my $max = $args{max};
   $max =~ s/\'//g;
   $max =~ s/\'//g;
   $command .= " -to $max";
  }
  if ($args{classinterval}) {
   my $ci = $args{classinterval};
   $ci =~ s/\'//g;
   $ci =~ s/\'//g;
   $command .= " -ci $ci";
  }
  if ($args{inputFile}) {
   my $input_file = $args{inputFile};
   chomp $input_file;
   my $tmp_input = `mktemp $TMP/classfreq-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_file;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  &run_WS_command($command, $output_choice, "classfreq", ".tab");
}

##########


sub convert_classes {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
  
  my $command = "$SCRIPTS/convert-classes";
  my $extension = undef;
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\"//g;
   $command .= " -from $in_format";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -to $out_format";
   if ($out_format eq 'profiles') {
     $extension = "tab"
   } else {
     $extension = $out_format;
   }

  }
  if ($args{member_col}) {
   my $member_col = $args{member_col};
   $member_col =~ s/\'//g;
   $member_col =~ s/\'//g;
   $command .= " -mcol $member_col";
  }
  if ($args{class_col}) {
   my $class_col = $args{class_col};
   $class_col =~ s/\'//g;
   $class_col =~ s/\'//g;
   $command .= " -ccol $class_col";
  }
  if ($args{score_col}) {
   my $score_col = $args{score_col};
   $score_col =~ s/\'//g;
   $score_col =~ s/\'//g;
   $command .= " -scol $score_col";
  }
  if ($args{min_score}) {
   my $score_col = $args{min_score};
   $min_score =~ s/\'//g;
   $min_score =~ s/\'//g;
   $command .= " -min_score $score_col";
  }
  if ($args{inputclasses}) {
   my $inputclasses = $args{inputclasses};
   chomp $inputclasses;
   my $tmp_input = `mktemp $TMP/convert-classes-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $inputclasses;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{names}) {
   my $inputclasses_names = $args{names};
   chomp $inputclasses_names;
   my $tmp_input = `mktemp $TMP/convert-classes-input-names.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $inputclasses_names;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -names '".$tmp_input."'";
  }
  &run_WS_command($command, $output_choice, "convert-classes", ".$extension");
}

##########
sub contingency_stats {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
  
  my $command = "$SCRIPTS/contingency-stats -v 1";
  
  if ($args{return}) {
   my $return = $args{return};
   $return =~ s/\'//g;
   $return =~ s/\'//g;
   $command .= " -return $return";
  }
  if ($args{decimals}) {
   my $decimals = $args{decimals};
   $decimals =~ s/\'//g;
   $decimals =~ s/\'//g;
   $command .= " -decimals $decimals";
  }
  if ($args{inputfile}) {
   my $inputfile = $args{inputfile};
   chomp $inputfile;
   my $tmp_input = `mktemp $TMP/contingency-stats-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $inputfile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{rsizes}) {
   my $inputfile = $args{rsizes};
   chomp $inputfile;
   my $tmp_input = `mktemp $TMP/contingency-stats-rsizes.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $inputfile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -rsizes '".$tmp_input."'";
  }
  if ($args{csizes}) {
   my $inputfile = $args{csizes};
   chomp $inputfile;
   my $tmp_input = `mktemp $TMP/contingency-stats-csizes.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $inputfile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -csizes '".$tmp_input."'";
  }
  &run_WS_command($command, $output_choice, "contingency-stats", ".tab");
}

##########
sub contingency_table {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
  
  my $command = "$SCRIPTS/contingency-table ";
  
  if ($args{null}) {
   my $null = $args{null};
   $null =~ s/\'//g;
   $null =~ s/\'//g;
   $command .= " -null $null";
  }
  if ($args{margin}) {
   $command .= " -margin";
  }
  if ($args{col1}) {
   my $col1 = $args{col1};
   $col1 =~ s/\'//g;
   $col1 =~ s/\'//g;
   $command .= " -col1 $col1";
  }
  if ($args{col2}) {
   my $col2 = $args{col2};
   $col2 =~ s/\'//g;
   $col2 =~ s/\'//g;
   $command .= " -col2 $col2";
  }
  if ($args{inputfile}) {
   my $inputfile = $args{inputfile};
   chomp $inputfile;
   my $tmp_input = `mktemp $TMP/contingency-table-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $inputfile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  open FILE, ">/home/rsat/rsa-tools/public_html/tmp/brol.truc3";
  &run_WS_command($command, $output_choice, "contingency-table", ".tab");
}

##########
sub xygraph {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;

    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $command = $self->xygraph_cmd(%args);
    ## IMAGE OUTPUT FORMAT RECUPERATION
    my $out_format = $args{format};
    $out_format =~ s/\'//g;
    $out_format =~ s/\'//g;
    my $tmp_outfile = `mktemp $TMP/xygraph.XXXXXXXXXX`;
    chomp $tmp_outfile;
    system("rm $tmp_outfile");
    $tmp_outfile .= ".$out_format";
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    close TMP_OUT;
    $command .= " -o $tmp_outfile";
    system $command;
    my $result = `cat $tmp_outfile`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
    }
    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"xy-graph",output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}

sub xygraph_cmd {
  my ($self, %args) =@_;

  my $command = "$SCRIPTS/XYgraph";

  if ($args{format}) {
   my $format = $args{format};
   $format =~ s/\'//g;
   $format =~ s/\'//g;
   $command .= " -format $format";
  }
  if ($args{title1}) {
   my $title1 = $args{title1};
   $title1 =~ s/\'//g;
   $title1 =~ s/\'//g;
   $command .= " -title1 '$title1'";
  }
  if ($args{lines}) {
   my $lines = $args{lines};
   $command .= " -lines";
  }
  if ($args{legend}) {
   my $legend = $args{legend};
   $command .= " -legend";
  }
  if ($args{header}) {
   my $header = $args{header};
   $command .= " -header";
  }
  if ($args{title2}) {
   my $title2 = $args{title2};
   $title2 =~ s/\'//g;
   $title2 =~ s/\'//g;
   $command .= " -title2 '$title2'";
  }
  if ($args{xleg1}) {
   my $xleg1 = $args{xleg1};
   $xleg1 =~ s/\'//g;
   $xleg1 =~ s/\'//g;
   $command .= " -xleg1 '$xleg1'";
  }
  if ($args{xleg2}) {
   my $xleg2 = $args{xleg2};
   $xleg2 =~ s/\'//g;
   $xleg2 =~ s/\'//g;
   $command .= " -xleg2 '$xleg2'";
  }
  if ($args{yleg1}) {
   my $yleg1 = $args{yleg1};
   $yleg1 =~ s/\'//g;
   $yleg1 =~ s/\'//g;
   $command .= " -yleg1 '$yleg1'";
  }
  if ($args{yleg2}) {
   my $yleg2 = $args{yleg2};
   $yleg2 =~ s/\'//g;
   $yleg2 =~ s/\'//g;
   $command .= " -yleg2 '$yleg2'";
  }
  if ($args{xmax} ne "") {
   my $xmax = $args{xmax};
   $xmax =~ s/\'//g;
   $xmax =~ s/\'//g;
   $command .= " -xmax $xmax";
  }
  if ($args{ymax} ne "") {
   my $ymax = $args{ymax};
   $ymax =~ s/\'//g;
   $ymax =~ s/\'//g;
   $command .= " -ymax $ymax";
  }
  if ($args{xmin} ne "") {
   my $xmin = $args{xmin};
   $xmin =~ s/\'//g;
   $xmin =~ s/\'//g;
   $command .= " -xmin $xmin";
  }
  if ($args{ymin} ne "") {
   my $ymin = $args{ymin};
   $ymin =~ s/\'//g;
   $ymin =~ s/\'//g;
   $command .= " -ymin $ymin";
  }
  if ($args{xlog} ne "") {
   my $xlog = $args{xlog};
   $xlog =~ s/\'//g;
   $xlog =~ s/\'//g;
   $command .= " -xlog $xlog";
  }
  if ($args{ylog} ne "") {
   my $ylog = $args{ylog};
   $ylog =~ s/\'//g;
   $ylog =~ s/\'//g;
   $command .= " -ylog $ylog";
  }
  if ($args{xcol} ne "") {
   my $xcol = $args{xcol};
   $xcol =~ s/\'//g;
   $xcol =~ s/\'//g;
   $command .= " -xcol $xcol";
  }
  if ($args{ycol}) {
   my $ycol = $args{ycol};
   $ycol =~ s/\'//g;
   $ycol =~ s/\'//g;
   $command .= " -ycol $ycol";
  }
  if ($args{inputFile}) {
   my $input_file = $args{inputFile};
   chomp $input_file;
   my $tmp_input = `mktemp $TMP/xygraph-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_file;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  return $command;
}

##########
sub convert_seq {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }

    if ($args{"sequence"}) {
	my $sequence = $args{"sequence"};
	chomp $sequence;
	$tmp_infile = `mktemp $TMP/convert-seq.XXXXXXXXXX`;
	open TMP_IN, ">".$tmp_infile or die "cannot open temp file ".$tmp_infile."\n";
	print TMP_IN $sequence;
	close TMP_IN;
    } elsif ($args{"tmp_infile"}) {
	$tmp_infile = $args{"tmp_infile"};
	$tmp_infile =~ s/\'//g;
	$tmp_infile =~ s/\"//g;
    }
    chomp $tmp_infile;
    my $command = "$SCRIPTS/convert-seq";

    if ($args{from}) {
	$args{from} =~ s/\'//g;
	$args{from} =~ s/\"//g;
	$command .= " -from '".$args{from}."'";
    }
    if ($args{to}) {
	$args{to} =~ s/\'//g;
	$args{to} =~ s/\"//g;
	$command .= " -to '".$args{to}."'";
    }

    $command .= " -i '".$tmp_infile."'";
    
    &run_WS_command($command, $output_choice, "convert-seq");
}

##########
sub compare_classes {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  #creation d'un fichier temporaire qui sera integre dans la commande
  if ($args{"ref_classes"}) {
    my $reference = $args{"ref_classes"};
    chomp $reference;
    $tmp_ref = `mktemp $TMP/compare-ref-classes.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_ref or die "cannot open temp file ".$tmp_ref."\n";
    print TMP_IN $reference;
    close TMP_IN;
  }
  #idem
  if ($args{"query_classes"}) {
    my $query = $args{"query_classes"};
    chomp $query;
    $tmp_query = `mktemp $TMP/compare-query-classes.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_query or die "cannot open temp file ".$tmp_query."\n";
    print TMP_IN $query;
    close TMP_IN;
  }
  if ($args{"input_classes"}) {
    my $input = $args{"input_classes"};
    chomp $input;
    $tmp_input = `mktemp $TMP/compare-input-classes.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
    print TMP_IN $input;
    close TMP_IN;
  }

  # my $ref_classes = $args{"ref_classes"};
  # my $query_classes = $args{"query_classes"};
  my $return_fields = $args{"return_fields"};
  my $score_column = $args{"score_column"};
  my $upper_threshold_field_list = $args{"upper_threshold_field"};
  my $upper_threshold_value_list = $args{"upper_threshold_value"};
  my $lower_threshold_field_list = $args{"lower_threshold_field"};
  my $lower_threshold_value_list = $args{"lower_threshold_value"};

  my $sort = $args{"sort"};
  my $distinct = $args{"distinct"};
  my $triangle = $args{"triangle"};
  my $matrix = $args{"matrix"};

  my $command = "$SCRIPTS/compare-classes -v 1";

  #pas d'utilite directe de "nettoyage" de la commande sauf si l'on rajoute un elsif...
  if ($tmp_ref) {
    $tmp_ref =~ s/\'//g;
    $tmp_ref =~ s/\"//g;
    chomp $tmp_ref;
    $command .= " -r '".$tmp_ref."'";
  }

  if ($tmp_query) {
    $tmp_query =~ s/\'//g;
    $tmp_query =~ s/\"//g;
    chomp $tmp_query;
    $command .= " -q '".$tmp_query."'";
  }

  if ($tmp_input) {
    $tmp_input =~ s/\'//g;
    $tmp_input =~ s/\"//g;
    chomp $tmp_input;
    $command .= " -i '".$tmp_input."'";
  }

  if ($return_fields) {
    $return_fields =~ s/\'//g;
    $return_fields =~ s/\"//g;
    $command .= " -return '".$return_fields."'";
  }

  if ($score_column) {
    $score_column =~ s/\'//g;
    $score_column =~ s/\"//g;
    $command .= " -sc '".$score_column."'";
  }

  if ($upper_threshold_field_list ne "" && $upper_threshold_value_list ne "")  {

    my @upper_threshold_field_cp = split(":", $upper_threshold_field_list);
    my @upper_threshold_value_cp = split(",", $upper_threshold_value_list);
    if (scalar(@upper_threshold_field_cp) == scalar(@upper_threshold_value_cp)) {
      for (my $i = 0; $i < scalar(@upper_threshold_field_cp); $i++) {
        my $upper_threshold_field = $upper_threshold_field_cp[$i];
        my $upper_threshold_value = $upper_threshold_value_cp[$i];
        $upper_threshold_field =~ s/\'//g;
        $upper_threshold_field =~ s/\"//g;
        $upper_threshold_value =~ s/\'//g;
        $upper_threshold_value =~ s/\"//g;
        $command .= " -uth '".$upper_threshold_field."' '".$upper_threshold_value."'";
      }
    }
  }

  if ($lower_threshold_field_list ne "" && $lower_threshold_value_list ne "")  {
    my @lower_threshold_field_cp = split(":", $lower_threshold_field_list);
    my @lower_threshold_value_cp = split(",", $lower_threshold_value_list);
    if (scalar(@lower_threshold_field_cp) == scalar(@lower_threshold_value_cp)) {
      for (my $i = 0; $i < scalar(@lower_threshold_field_cp); $i++) {
        my $lower_threshold_field = $lower_threshold_field_cp[$i];
        my $lower_threshold_value = $lower_threshold_value_cp[$i];
        $lower_threshold_field =~ s/\'//g;
        $lower_threshold_field =~ s/\"//g;
        $lower_threshold_value =~ s/\'//g;
        $lower_threshold_value =~ s/\"//g;
        $command .= " -lth '".$lower_threshold_field."' '".$lower_threshold_value."'";
      }
    }
  }

  if ($sort) {
    $sort =~ s/\'//g;
    $sort =~ s/\"//g;
    $command .= " -sort '".$sort."'";
  }

  if ($distinct == 1) {
    $command .= " -distinct";
  }

  if ($triangle == 1) {
    $command .= " -triangle";
  }

  if ($matrix) {
    $matrix =~ s/\'//g;
    $matrix =~ s/\"//g;
    $command .= " -matrix '".$matrix."'";
  }

 &run_WS_command($command, $output_choice, "compare-classes", ".tab");
}

##########
sub matrix_scan {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
#   my $command = $self->matrix_scan_cmd(%args);
#   my $stderr = `$command 2>&1 1>/dev/null`;  ####cette gestion des erreurs est incompatible avec le fonctionnement de matrix-scan dans RSAT #######
#   if ($stderr) {
#     die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
#   }
#   my $result = `$command`;
#   my $tmp_outfile = `mktemp $TMP/matrix-scan.XXXXXXXXXX`;
#   open TMP, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
#   print TMP $result;
#   close TMP;
#   if ($output_choice eq 'server') {
#     return SOAP::Data->name('response' => {'command' => $command, 
# 					   'server' => $tmp_outfile});
#   } elsif ($output_choice eq 'client') {
#     return SOAP::Data->name('response' => {'command' => $command,
# 					   'client' => $result});
#   } elsif ($output_choice eq 'both') {
#     return SOAP::Data->name('response' => {'server' => $tmp_outfile,
# 					   'command' => $command, 
# 					   'client' => $result});
#   }
# }

# sub matrix_scan_cmd {
#   my ($self,%args) = @_;

  #creation d'un fichier temporaire qui sera integre dans la commande
  if ($args{"sequence"}) {
    my $sequence = $args{"sequence"};
    chomp $sequence;
    $tmp_sequence_infile = `mktemp $TMP/matscan-sequence.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_sequence_infile or die "cannot open temp file ".$tmp_sequence_infile."\n";
    print TMP_IN $sequence;
    close TMP_IN;
  } elsif ($args{tmp_sequence_infile}){
      $tmp_sequence_infile = $args{"tmp_sequence_infile"};
  }
  chomp $tmp_sequence_infile;

  #idem
  if ($args{"matrix"}) {
      my $input_matrix = $args{"matrix"};
      chomp $input_matrix;
      $tmp_matrix_infile = `mktemp $TMP/matscan-matrix.XXXXXXXXXX`;
      open TMP_IN, ">".$tmp_matrix_infile or die "cannot open temp file ".$tmp_matrix_infile."\n";
      print TMP_IN $input_matrix;
      close TMP_IN;
  } elsif ($args{tmp_matrix_infile}){
      $tmp_matrix_infile = $args{"tmp_matrix_infile"};
  }
  chomp $tmp_matrix_infile;
  
#  if ($args{"matrix_list"}) {
#      my $input_list = $args{"matrix_list"};
#      chomp $input_list;
#      $tmp_input_list = `mktemp $TMP/matscan-matrix_list.XXXXXXXXXX`;
#      open TMP_IN, ">".$tmp_input_list or die "cannot open temp file ".$tmp_input_list."\n";
#      print TMP_IN $input_list;
#      close TMP_IN;
#  }

  my $sequence_format = $args{"sequence_format"}; 
  my $matrix_format = $args{"matrix_format"}; 
  my $top_matrices = $args{"top_matrices"};
  my $background_input = $args{"background_input"};
  my $background_window = $args{"background_window"};
  my $markov = $args{"markov"};
  my $background_pseudo = $args{"background_pseudo"};
  my $return_fields = $args{"return_fields"};
  my $str = $args{"str"};
  my $verbosity = $args{"verbosity"};
  my $origin = $args{"origin"};
  my $decimals = $args{"decimals"};
  my $crer_ids = $args{"crer_ids"};

    ## List of lower thresholds
    my $lth_ref = $args{"lth"};
    my $lth = "";
    if ($lth_ref =~ /ARRAY/) {
      my @lth = @{$lth_ref};
      foreach $lt (@lth) {
	$lt =~s/\'//g;
	$lt =~s/\"//g;
	@_lt = split / /, $lt;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
      }
    } elsif ($lth_ref) {
	@_lt = split / /, $lth_ref;
	$lth .= " -lth '".$_lt[0]."' '".$_lt[1]."'";
}

    ## List of upper thresholds
    my $uth_ref = $args{"uth"};
    my $uth = "";
    if ($uth_ref =~ /ARRAY/) {
      my @uth = @{$uth_ref};
      foreach $ut (@uth) {
	$ut =~s/\'//g;
	$ut =~s/\"//g;
	@_ut = split / /, $ut;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
      }
    } elsif ($uth_ref) {
	@_ut = split / /, $uth_ref;
	$uth .= " -uth '".$_ut[0]."' '".$_ut[1]."'";
    }

  my $command = "$SCRIPTS/matrix-scan";

  if ($tmp_sequence_infile) {
      $tmp_sequence_infile =~ s/\'//g;
      $tmp_sequence_infile =~ s/\"//g;
      chomp $tmp_sequence_infile;
      $command .= " -i '".$tmp_sequence_infile."'";
  }

  if ($tmp_matrix_infile) {
      $tmp_matrix_infile =~ s/\'//g;
      $tmp_matrix_infile =~ s/\"//g;
      chomp $tmp_matrix_infile;
      $command .= " -m '".$tmp_matrix_infile."'";
  }

  if ($sequence_format) {
      $sequence_format =~ s/\'//g;
      $sequence_format=~ s/\"//g;
      chomp $sequence_format;
      $command .= " -seq_format '".$sequence_format."'";
  }

  if ($matrix_format) {
      $matrix_format =~ s/\'//g;
      $matrix_format=~ s/\"//g;
      chomp $matrix_format;
      $command .= " -matrix_format '".$matrix_format."'";
  }

  if ($args{"n_treatment"} eq "score" || $args{"n_treatment"} eq "skip") {
      $command .= " -n ".$args{"n_treatment"};
  } else {
      die "n_treatment value must be score or skip";
  }

  if ($args{"consensus_name"} == 1 ) {
      $command .= " -consensus_name";
  }

  if ($args{"pseudo"} =~ /\d/) {
      $args{"pseudo"}  =~ s/\'//g;
      $args{"pseudo"} =~ s/\"//g;
      $command .= " -pseudo '".$args{"pseudo"}."'";
  }

if ($args{"equi_pseudo"} == 1 ) {
      $command .= " -equi_pseudo";
  }

#  if ($tmp_input_list) {
#      $tmp_input_list =~ s/\'//g;
#      $tmp_input_list =~ s/\"//g;
#      $command .= " -mlist '".$tmp_input_list."'";
# }

  if ($top_matrices ) {
      $top_matrices  =~ s/\'//g;
      $top_matrices  =~ s/\"//g;
      $command .= " -top_matrices '".$top_matrices."'";
  }

  if ($args{"background_model"}) {
      my $background = $args{"background_model"};
      chomp $background;
      $tmp_background_infile = `mktemp $TMP/matscan-background.XXXXXXXXXX`;
      open TMP_IN, ">".$tmp_background_infile or die "cannot open temp file ".$tmp_background_infile ."\n";
      print TMP_IN $background;
      close TMP_IN; 
  } elsif ($args{"tmp_background_infile"}) {
      $tmp_background_infile = $args{"tmp_background_infile"};
  } elsif ($args{"background"} && ($args{"markov"} =~ /\d/)){
      $oligo_length = $args{"markov"} + 1;
      if ($args{"organism"}) {

## sub not found => HELP, Jacques!
#	  $tmp_background_infile = &ExpectedFreqFile($args{"organism"}, $oligo_length, $args{"background"},
#			    str=>'-1str',noov=>'-ovlp',type=>'oligo', warn=>0, taxon=>0);
	  $tmp_background_infile = "/home/rsat/rsa-tools/data/genomes/".$args{"organism"}."/oligo-frequencies/".$oligo_length."nt_".$args{"background"}."_".$args{"organism"}."-ovlp-1str.freq.gz";

## Only noov taxon bckgds available at the moment => useless
#      } elsif ($args{"taxon"}) {
#	  $tmp_background_infile = &ExpectedFreqFile($args{"taxon"}, $oligo_length, $args{"background"},
#					       str=>'-1str',noov=>'-ovlp',type=>'oligo', warn=>0, taxon=>1);
#	  $tmp_background_infile = ;
      } else {
	  die "You must provide either an organism or a taxon name";
      }
  }

  if ($tmp_background_infile) {
      $tmp_background_infile  =~ s/\'//g;
      $tmp_background_infile  =~ s/\"//g;
      chomp $tmp_background_infile;
      $command .= " -bgfile '".$tmp_background_infile."'";
  }

 if ($background_input == 1 ) {
      $command .= " -bginput";
  }

  if ($background_window) {
      $background_window  =~ s/\'//g;
      $background_window=~ s/\"//g;
      $command .= " -window '".$background_window."'";
  }

  if (($markov =~ /\d/) && !$args{"background"}) {
      $markov  =~ s/\'//g;
      $markov =~ s/\"//g;
      $command .= " -markov '".$markov."'";
  }

  if ($background_pseudo) {
      $background_pseudo =~ s/\'//g;
      $background_pseudo =~ s/\"//g;
      $command .= " -bg_pseudo '".$background_pseudo."'";
  }

  if ($return_fields) {
      $return_fields =~ s/\'//g;
      $return_fields =~ s/\"//g;
      $command .= " -return '".$return_fields."'";
  }

  if ($lth) {
    $command .= $lth;
  }

  if ($uth) {
    $command .= $uth;
  }

  if ($str =~ /\d/) {
      if ($str == 1 || $str == 2) {
	  $command .= " -".$str."str";
      } else {
	  die "str value must be 1 or 2";
      }
  }

  if ($verbosity =~ /\d/) {
      $verbosity =~ s/\'//g;
      $verbosity =~ s/\"//g;
      $command .= " -v '".$verbosity."'";
  }

  if ($origin =~ /\d/) {
      $origin =~ s/\'//g;
      $origin =~ s/\"//g;
      $command .= " -origin '".$origin."'";
  }

  if ($decimals =~ /\d/) {
      $decimals =~ s/\'//g;
      $decimals =~ s/\"//g;
      $command .= " -decimals '".$decimals."'";
  }

  if ($crer_ids == 1) {
      $command .= " -crer_ids";
  }

 &run_WS_command($command, $output_choice, ".matrix-scan")
}

##########
sub matrix_distrib {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }

  if ($args{"matrix_file"}) {
    my $input_matrix = $args{"matrix_file"};
    chomp $input_matrix;
    $tmp_input_matrix = `mktemp $TMP/matdistrib-matrix_file.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_input_matrix or die "cannot open temp file ".$tmp_input_matrix."\n";
    print TMP_IN $input_matrix;
    close TMP_IN;
  }  elsif ($args{"tmp_matrix_file"}) {
    $tmp_input_matrix = $args{"tmp_matrix_file"};
    $tmp_input_matrix =~ s/\'//g;
    $tmp_input_matrix =~ s/\"//g;
  }

  if ($args{"background"}) {
    my $background = $args{"background"};
    chomp $background;
    $tmp_background = `mktemp $TMP/matdistrib-background.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_background or die "cannot open temp file ".$tmp_background ."\n";
    print TMP_IN $background;
    close TMP_IN;
  }

  my $matrix_format = $args{"matrix_format"}; 
  my $background_pseudo = $args{"background_pseudo"};
  my $background_format = $args{"background_format"}; 
  my $pseudo = $args{"matrix_pseudo"};
  my $decimals = $args{"decimals"};

  my $command = "$SCRIPTS/matrix-distrib -v 1";

  if ($tmp_input_matrix) {
    $tmp_input_matrix =~ s/\'//g;
    $tmp_input_matrix =~ s/\"//g;
    chomp $tmp_input_matrix;
    $command .= " -m '".$tmp_input_matrix."'";
  }

  if ($matrix_format) {
    $matrix_format =~ s/\'//g;
    $matrix_format=~ s/\"//g;
    chomp $matrix_format;
    $command .= " -matrix_format '".$matrix_format."'";
  }

  if ($pseudo =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $pseudo =~ s/\'//g;
    $pseudo =~ s/\"//g;
    $command .= " -pseudo '".$pseudo."'";
  }

  if ($decimals =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $decimals  =~ s/\'//g;
    $decimals  =~ s/\"//g;
    $command .= " -decimals '".$decimals."'";
  }

  if ($tmp_background) {
    $tmp_background  =~ s/\'//g;
    $tmp_background  =~ s/\"//g;
    chomp $tmp_background;
    $command .= " -bgfile '".$tmp_background."'";
  }

  if ($background_format) {
    $background_format  =~ s/\'//g;
    $background_format  =~ s/\"//g;
    $command .= " -bg_format '".$background_format."'";
  }

  if ($background_pseudo =~ /\d/) { ## This is to make the difference between unspecified parameter and value 0
    $background_pseudo =~ s/\'//g;
    $background_pseudo =~ s/\"//g;
    $command .= " -bg_pseudo '".$background_pseudo."'";
  }

  &run_WS_command($command, $output_choice, ".matrix-distrib")
}

##########
sub random_seq {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }

  my $command = "$SCRIPTS/random-seq";

  if ($args{sequence_length}) {
      $args{sequence_length} =~ s/\'//g;
      $args{sequence_length} =~ s/\"//g;
      $command .= " -l '".$args{sequence_length}."'";
  }
  if ($args{repetition}) {
      $args{repetition} =~ s/\'//g;
      $args{repetition} =~ s/\"//g;
      $command .= " -n '".$args{repetition}."'";
  }
  if ($args{format}) {
      $args{format} =~ s/\'//g;
      $args{format} =~ s/\"//g;
      $command .= " -format '".$args{format}."'";
  }
  if ($args{line_width} =~ /\d/) {
      $args{line_width} =~ s/\'//g;
      $args{line_width} =~ s/\"//g;
      $command .= " -lw '".$args{line_width}."'";
  }
  if ($args{type}) {
      $args{type} =~ s/\'//g;
      $args{type} =~ s/\"//g;
      $command .= " -type '".$args{type}."'";
  }
  if ($args{seed}) {
      $args{seed} =~ s/\'//g;
      $args{seed} =~ s/\"//g;
      $command .= " -seed '".$args{seed}."'";
  }
  if ($args{alphabet}) {
      $args{alphabet} =~ s/\'//g;
      $args{alphabet} =~ s/\"//g;
      $command .= " -a '".$args{alphabet}."'";
  }
  if ($args{bg_model}) {
      $args{bg_model} =~ s/\'//g;
      $args{bg_model} =~ s/\"//g;
      $command .= " -bg '".$args{bg_model}."'";
  }
  if ($args{organism}) {
      $args{organism} =~ s/\'//g;
      $args{aorganism} =~ s/\"//g;
      $command .= " -org '".$args{organism}."'";
  }
  if ($args{oligo_length}) {
      $args{oligo_length} =~ s/\'//g;
      $args{oligo_length} =~ s/\"//g;
      $command .= " -ol '".$args{oligo_length}."'";
  }
  if ($args{"expfreq"}) {
    my $expfreq = $args{"expfreq"};
    chomp $expfreq;
    $tmp_expfreq = `mktemp $TMP/expfreq.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_expfreq or die "cannot open temp file ".$tmp_expfreq."\n";
    print TMP_IN $expfreq;
    close TMP_IN;
    chomp $tmp_expfreq;
    $command .= " -expfreq '".$tmp_expfreq."'";
  } elsif ($args{"tmp_expfreq_file"}) {
    $tmp_expfreq = $args{"tmp_expfreq_file"};
    $tmp_expfreq =~ s/\'//g;
    $tmp_expfreq =~ s/\"//g;
    chomp $tmp_expfreq;
    $command .= " -expfreq '".$tmp_expfreq."'";
  }
  if ($args{length_file}) {
    my $length_file = $args{length_file};
    chomp $length_file;
    $tmp_length = `mktemp $TMP/length.XXXXXXXXXX`;
    open TMP_IN, ">".$tmp_length or die "cannot open temp file ".$tmp_length."\n";
    print TMP_IN $length_file;
    close TMP_IN;
    chomp $tmp_length;
    $command .= " -lf '".$tmp_length."'";
  } elsif ($args{tmp_length_file}) {
    $tmp_length  = $args{tmp_length_file};
    $tmp_length =~ s/\'//g;
    $tmp_length =~ s/\"//g;
    chomp $tmp_length;
    $command .= " -lf '".$tmp_length."'";
  }

 &run_WS_command($command, $output_choice, ".random-seq")
}

# RSAT GRAPH TOOLS
##########

sub convert_graph {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $tmp_outfile = `mktemp $TMP/convert-graph.XXXXXXXXXX`;
    my $out_format = $args{outformat};
    $out_format =~ s/\'//g;
    $out_format =~ s/\'//g;
    chop $tmp_outfile;
    system("rm $tmp_outfile");
    $tmp_outfile .= ".$out_format";

    
    
    
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
#     print TMP_OUT $result;
#     print TMP_OUT "KEYS ".keys(%args);
    close TMP_OUT;
    my $command = $self->convert_graph_cmd(%args);
    $command .= " -o $tmp_outfile";
    system $command;
    my $result = `cat $tmp_outfile`;
    my $stderr = `$command 2>&1 1>/dev/null`;

    if ($stderr) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");

    }

    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"convert-graph",output_choice=>$output_choice);
    
    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
#           open TRUC, ">/home/rsat/rsa-tools/public_html/tmp/truc.brol";
    print TRUC "$result";
    close TRUC;  
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}

sub convert_graph_cmd {
  my ($self, %args) =@_;
  
  my $command = "$SCRIPTS/convert-graph ";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\"//g;
   $command .= " -from $in_format";
  }
  if ($args{ecolors}) {
   my $col_scale = $args{ecolors};
   $col_scale =~ s/\'//g;
   $col_scale =~ s/\"//g;
   $command .= " -ecolors $col_scale";
  }
  if ($args{undirected}) {
   $command .= " -undirected";
  }
  if ($args{ewidth}) {
   $command .= " -ewidth";
  }
  if ($args{layout}) {
   $command .= " -layout";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -to $out_format";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{eccol}) {
   my $eccol = $args{eccol};
   $eccol =~ s/\'//g;
   $eccol =~ s/\'//g;
   $command .= " -eccol $eccol";
  }
  if ($args{tccol}) {
   my $tccol = $args{tccol};
   $tccol =~ s/\'//g;
   $tccol =~ s/\'//g;
   $command .= " -tccol $tccol";
  }
  if ($args{sccol}) {
   my $sccol = $args{sccol};
   $sccol =~ s/\'//g;
   $sccol =~ s/\'//g;
   $command .= " -sccol $sccol";
  }
  if ($args{pathcol}) {
   my $pathcol = $args{pathcol};
   $pathcol =~ s/\'//g;
   $pathcol =~ s/\'//g;
   $command .= " -pathcol $pathcol";
  }
  if ($args{distinct_path}) {
   $command .= " -distinct_path";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/convert-graph-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  return $command;
}

##########
sub alter_graph {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  
  my $command = "$SCRIPTS/alter-graph";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\"//g;
   $command .= " -in_format $in_format";
  }
  if ($args{duplicate}) {
   $command .= " -duplicate";
  }
  if ($args{directed}) {
   $command .= " -directed";
  }
  if ($args{self}) {
   $command .= " -self";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -out_format $out_format";
  }
  if ($args{add_nodes}) {
   my $add_nodes = $args{add_nodes};
   $add_nodes =~ s/\'//g;
   $add_nodes =~ s/\'//g;
   $command .= " -add_nodes $add_nodes";
  }
  if ($args{rm_nodes}) {
   my $rm_nodes = $args{rm_nodes};
   $rm_nodes =~ s/\'//g;
   $rm_nodes =~ s/\'//g;
   $command .= " -rm_nodes $rm_nodes";
  }
  if ($args{add_edges}) {
   my $add_edges = $args{add_edges};
   $add_edges =~ s/\'//g;
   $add_edges =~ s/\'//g;
   $command .= " -add_edges $add_edges";
  }
  if ($args{rm_edges}) {
   my $rm_edges = $args{rm_edges};
   $rm_edges =~ s/\'//g;
   $rm_edges =~ s/\'//g;
   $command .= " -rm_edges $rm_edges";
  }  
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{target}) {
   my $target = $args{target};
   $target =~ s/\'//g;
   $target =~ s/\'//g;
   $command .= " -target $target";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/alter-graph-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  my $extension = $args{outformat} || "tab";
  &run_WS_command($command, $output_choice, "alter-graph", ".$extension");
}
##########
sub graph_cliques {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  
  my $command = "$SCRIPTS/graph-cliques";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\"//g;
   $command .= " -in_format $in_format";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{min_size}) {
   my $min_size = $args{min_size};
   $min_size =~ s/\'//g;
   $min_size =~ s/\'//g;
   $command .= " -min_size $min_size";
  }
  if ($args{max_size}) {
   my $max_size = $args{max_size};
   $max_size =~ s/\'//g;
   $max_size =~ s/\'//g;
   $command .= " -max_size $max_size";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/graph-clique-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }

    
  &run_WS_command($command, $output_choice, "graph-clique", ".tab");
}
##########
sub display_graph {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;

    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $command = $self->display_graph_cmd(%args);
    ## IMAGE OUTPUT FORMAT RECUPERATION
    my $out_format = $args{outformat};
    $out_format =~ s/\'//g;
    $out_format =~ s/\'//g;
    my $tmp_outfile = `mktemp $TMP/display_graph.XXXXXXXXXX`;
    chop $tmp_outfile;
    system("rm $tmp_outfile");
    $tmp_outfile .= ".$out_format";
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    close TMP_OUT;
    $command .= " -o $tmp_outfile";
    
    system $command;
    
    
    
    my $result = `cat $tmp_outfile`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
    }

        &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"display-graph",output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
     
}

sub display_graph_cmd {
  my ($self, %args) =@_;
  
  my $command = "$SCRIPTS/display-graph";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{layout}) {
   $command .= " -layout";
  }
  if ($args{ewidth}) {
   $command .= " -ewidth";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -out_format $out_format";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{eccol}) {
   my $eccol = $args{eccol};
   $eccol =~ s/\'//g;
   $eccol =~ s/\'//g;
   $command .= " -eccol $eccol";
  }
  if ($args{tccol}) {
   my $tccol = $args{tccol};
   $tccol =~ s/\'//g;
   $tccol =~ s/\'//g;
   $command .= " -tccol $tccol";
  }
  if ($args{sccol}) {
   my $sccol = $args{sccol};
   $sccol =~ s/\'//g;
   $sccol =~ s/\'//g;
   $command .= " -sccol $sccol";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/display-graph-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  
  return $command;
}



######################
##########
sub draw_heatmap {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    
    open TEMP, ">/home/rsat/rsa-tools/public_html/tmp/newtest";
    print TEMP join ("", %args);

    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $command = $self->draw_heatmap_cmd(%args);
    ## IMAGE OUTPUT FORMAT RECUPERATION
    my $out_format = $args{outformat} || "png";
    $out_format =~ s/\'//g;
    $out_format =~ s/\'//g;
    my $tmp_outfile = `mktemp $TMP/draw-heatmap.XXXXXXXXXX`;
    chomp $tmp_outfile;
    system("rm $tmp_outfile");
    $tmp_outfile .= ".$out_format";
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    close TMP_OUT;
    my $tmp_outfile_html = $tmp_outfile.".html";
    $command .= " -o $tmp_outfile";
    if ($args {html}) {
      $command .= " -html $tmp_outfile_html";
    }
    my $result = `cat $tmp_outfile`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
    }

        &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"draw-heatmap",output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
     
}

sub draw_heatmap_cmd {
  my ($self, %args) = @_;
  
  my $command = "$SCRIPTS/draw-heatmap";
  
  if ($args{no_text}) {
   $command .= " -notext";
  }
  if ($args{row_names}) {
   $command .= " -rownames";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -out_format $out_format";
  }
  if ($args{gradient}) {
   my $gradient = $args{gradient};
   $gradient =~ s/\'//g;
   $gradient =~ s/\'//g;
   $command .= " -gradient $gradient";
  }
  if ($args{min}) {
   my $min = $args{min};
   $min =~ s/\'//g;
   $min =~ s/\'//g;
   $command .= " -min $min";
  }
  if ($args{max}) {
   my $max = $args{max};
   $max =~ s/\'//g;
   $max =~ s/\'//g;
   $command .= " -max $max";
  }
  if ($args{col_width}) {
   my $col_width = $args{col_width};
   $col_width =~ s/\'//g;
   $col_width =~ s/\'//g;
   $command .= " -col_width $col_width";
  }
  if ($args{row_height}) {
   my $row_height = $args{row_height};
   $row_height =~ s/\'//g;
   $row_height =~ s/\'//g;
   $command .= " -row_height $row_height";
  }
  if ($args{inputfile}) {
   my $input_file = $args{inputfile};
   chomp $input_file;
   my $tmp_input = `mktemp $TMP/draw-heatmap-input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $input_file;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  
  return $command;
}





##########
# sub graph_get_clusters {
#     my ($self, $args_ref) = @_;
#     my %args = %$args_ref;
#     my $output_choice = $args{"output"};
#     unless ($output_choice) {
# 	$output_choice = 'both';
#     }
#     my $command = $self->graph_get_clusters_cmd(%args);
#     my $result = `$command`;
#     my $stderr = `$command 2>&1 1>/dev/null`;
#     if ($stderr) {
# 	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
#     }
#     my $tmp_outfile = `mktemp $TMP/graph-get-clusters-out.XXXXXXXXXX`;
#     open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
#     print TMP_OUT $result;
# #     print TMP_OUT "KEYS ".keys(%args);
#     close TMP_OUT;
#     if ($output_choice eq 'server') {
# 	return SOAP::Data->name('response' => {'command' => $command, 
# 					       'server' => $tmp_outfile});
#     } elsif ($output_choice eq 'client') {
# 	return SOAP::Data->name('response' => {'command' => $command,
# 					       'client' => $result});
#     } elsif ($output_choice eq 'both') {
# 	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
# 					       'command' => $command, 
# 					       'client' => $result});
#     }
# }

sub graph_get_clusters {
  
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  
  my $command = "$SCRIPTS/graph-get-clusters ";
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -out_format $out_format";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{return}) {
   my $return = $args{return};
   $return =~ s/\'//g;
   $return =~ s/\'//g;
   $command .= " -return $return";
  }
  if ($args{induced}) {
   my $tcol = $args{tcol};
   $command .= " -induced";
  }
  if ($args{distinct}) {
   my $tcol = $args{tcol};
   $command .= " -distinct";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/graph-get-clusters-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{clusters}) {
   my $input_clusters = $args{clusters};
   chomp $input_clusters;
   my $tmp_input = `mktemp $TMP/graph-get-clusters-input-clusters.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open clusters temp file ".$tmp_input."\n";
   print TMP_IN $input_clusters;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -clusters '".$tmp_input."'";
  }
  my $extension = $args{outformat} || "tab";
  &run_WS_command($command, $output_choice, "graph-get-clusters", ".$extension");
}




sub graph_node_degree {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  my $command = "$SCRIPTS/graph-node-degree";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{all}) {
   my $tcol = $args{tcol};
   $command .= " -all";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/graph-node-degree-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{nodefile}) {
   my $nodefile = $args{nodefile};
   chomp $nodefile;
   my $tmp_input = `mktemp $TMP/graph-node-degree-input-nodes.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open clusters temp file ".$tmp_input."\n";
   print TMP_IN $nodefile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -nodef '".$tmp_input."'";
  }
  &run_WS_command($command, $output_choice, "graph-node-degree", ".tab");

}


#################################
# graph-topology

sub graph_topology {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $tmp_outfile = `mktemp $TMP/graph_topology.XXXXXXXXXX`;
    chomp $tmp_outfile;
    $tmp_outfile.".tab";
    system ("rm $tmp_outfile");
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
#     print TMP_OUT $result;
#     print TMP_OUT "KEYS ".keys(%args);
    close TMP_OUT;
    my $command = $self->graph_topology_cmd(%args);
    $command .= " -o '$tmp_outfile'";

    system $command;
    my $result = `cat $tmp_outfile`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");

    }

    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"graph_topology",output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}



sub graph_topology_cmd {
  my ($self, %args) = @_;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  my $command = "$SCRIPTS/graph-topology";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{all}) {
   my $tcol = $args{tcol};
   $command .= " -all";
  }
  if ($args{directed}) {
   $command .= " -directed";
  }
  if ($args{'return'}) {
   my $return = $args{'return'};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -return $return";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/graph-topology-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{nodefile}) {
   my $nodefile = $args{nodefile};
   chomp $nodefile;
   my $tmp_input = `mktemp $TMP/graph-topology-input-nodes.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open clusters temp file ".$tmp_input."\n";
   print TMP_IN $nodefile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -nodef '".$tmp_input."'";
  }
  return ($command);

}

##########
sub graph_cluster_membership {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $command = $self->graph_cluster_membership_cmd(%args);
    my $result = `$command`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr != "" && $stderr !~ /INFO/ && $stderr !~ /WARNING/) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
    }
    my $tmp_outfile = `mktemp $TMP/graph-cluster-membership-out.XXXXXXXXXX`;
    chomp($tmp_outfile);
    my $prefix = $tmp_outfile;
    my $tmp_comments = $prefix.".tab.comments";
    $tmp_outfile = $prefix.".tab";
    
    system("rm $tmp_outfile");
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    print TMP_OUT $result;

#     print TMP_OUT "KEYS ".keys(%args);
    close TMP_OUT;
    # Print the comments
    open COMMENTS_OUT, ">".$tmp_comments or die "cannot open temp file ".$tmp_comments."\n";
    print COMMENTS_OUT $stderr;
    close COMMENTS_OUT;
    
    
    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"graph-cluster-membership",output_choice=>$output_choice);
    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}

sub graph_cluster_membership_cmd {
  my ($self, %args) =@_;
  
  my $command = "$SCRIPTS/graph-cluster-membership";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{stat}) {
   my $stat = $args{stat};
   $stat =~ s/\'//g;
   $stat =~ s/\'//g;
   $command .= " -stat $stat";
  }
  if ($args{decimals}) {
   my $decimals = $args{decimals};
   $decimals =~ s/\'//g;
   $decimals =~ s/\'//g;
   $command .= " -decimals $decimals";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }

  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/graph-cluster-membership-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{clusters}) {
   my $clusters = $args{clusters};
   chomp $clusters;
   my $tmp_input = `mktemp $TMP/graph-cluster-membership-clusters.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open clusters temp file ".$tmp_input."\n";
   print TMP_IN $clusters;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -clusters '".$tmp_input."'";
  }
  return $command;
}

##########
sub compare_graphs {
    ## In order to recuperate the statistics calculated
    ## by compare-graphs, I place all the standard error
    ## in a separate file but. However the computation is
    ## blocked if the standard error contains the word "Error" 
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    my $command = $self->compare_graphs_cmd(%args);
    my $result = `$command`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    if ($stderr =~ /Warning/) {
	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
    }
    my $tmp_outfile = `mktemp $TMP/compare-graphs-out.XXXXXXXXXX`;
    chomp($tmp_outfile);
    my $extension = $args{outformat} || "tab";
    $tmp_outfile .= ".$extension";
    system ("rm $tmp_outfile");
    
    my $tmp_comments = $tmp_outfile.".comments";
    # Print the results
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    print TMP_OUT $result;
    close TMP_OUT;
    # Print the comments
    open COMMENTS_OUT, ">".$tmp_comments or die "cannot open temp file ".$tmp_comments."\n";
    print COMMENTS_OUT $stderr;
    close COMMENTS_OUT;
    &UpdateLogFileWS(command=>$command, tmp_outfile=>$tmp_outfile, method_name=>"compare-graphs",output_choice=>$output_choice);
    
    
    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
    
}

sub compare_graphs_cmd {
  my ($self, %args) =@_;
  
  my $command = "$SCRIPTS/compare-graphs -v 1 ";
  
  if ($args{Qinformat}) {
   my $Qin_format = $args{Qinformat};
   $Qin_format =~ s/\'//g;
   $Qin_format =~ s/\'//g;
   $command .= " -in_format_Q $Qin_format";
  }
  if ($args{Rinformat}) {
   my $Rin_format = $args{Rinformat};
   $Rin_format =~ s/\'//g;
   $Rin_format =~ s/\'//g;
   $command .= " -in_format_R $Rin_format";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -out_format $out_format";
  }
  if ($args{outweight}) {
   my $outweight = $args{outweight};
   $outweight =~ s/\'//g;
   $outweight =~ s/\'//g;
   $command .= " -outweight $outweight";
  }
  if ($args{return}) {
   my $return = $args{return};
   $return =~ s/\'//g;
   $return =~ s/\'//g;
   $command .= " -return $return";
  }
  if ($args{Qwcol}) {
   my $wcol_q = $args{Qwcol};
   $wcol_q =~ s/\'//g;
   $wcol_q =~ s/\'//g;
   $command .= " -wcol_Q $wcol_q";
  }
  if ($args{Qscol}) {
   my $scol_q = $args{Qscol};
   $scol_q =~ s/\'//g;
   $scol_q =~ s/\'//g;
   $command .= " -scol_Q $scol_q";
  }
  if ($args{Qtcol}) {
   my $tcol_q = $args{Qtcol};
   $tcol_q =~ s/\'//g;
   $tcol_q =~ s/\'//g;
   $command .= " -tcol_Q $tcol_q";
  }
  if ($args{Rwcol}) {
   my $wcol_r = $args{Rwcol};
   $wcol_r =~ s/\'//g;
   $wcol_r =~ s/\'//g;
   $command .= " -wcol_R $wcol_r";
  }
  if ($args{Rscol}) {
   my $scol_r = $args{Rscol};
   $scol_r =~ s/\'//g;
   $scol_r =~ s/\'//g;
   $command .= " -scol_R $scol_r";
  }
  if ($args{Rtcol}) {
   my $tcol_r = $args{Rtcol};
   $tcol_r =~ s/\'//g;
   $tcol_r =~ s/\'//g;
   $command .= " -tcol_R $tcol_r";
  }
  if ($args{Qinputgraph}) {
   my $input_graph = $args{Qinputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/compare-graphs-query-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -Q '".$tmp_input."'";
  }
  if ($args{Rinputgraph}) {
   my $input_graph = $args{Rinputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/compare-graphs-reference-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -R '".$tmp_input."'";
  }
  return $command;
}

##########
sub graph_neighbours {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  
  my $command = "$SCRIPTS/graph-neighbours";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{steps}) {
   my $steps = $args{steps};
   $steps =~ s/\'//g;
   $steps =~ s/\'//g;
   $command .= " -steps $steps";
  }
  if ($args{all}) {
   $command .= " -all";
  }
  if ($args{stats}) {
   my $stats = $args{stats};
   $command .= " -stats";
  }
  if ($args{direction}) {
   my $direction = $args{direction};
   $direction =~ s/\'//g;
   $direction =~ s/\'//g;
   $command .= " -direction $direction";
  }
  if ($args{self}) {
   my $self = $args{self};
   $command .= " -self";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/graph_neighbours-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{seedfile}) {
   my $seedfile = $args{seedfile};
   chomp $seedfile;
   my $tmp_input = `mktemp $TMP/graph_neighbours-seed-nodes.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open clusters temp file ".$tmp_input."\n";
   print TMP_IN $seedfile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -seedf '".$tmp_input."'";
  }
  &run_WS_command($command, $output_choice, "graph-neighbours", ".tab");
}



##########
sub rnsc {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    
    my $command = $self->rnsc_cmd(%args);
    my $tmp_outfile = `mktemp $TMP/rnsc-out.XXXXXXXXXX`;
    chomp $tmp_outfile;
    $tmp_logfile = $tmp_outfile.".log";
    
    $command .= " -o $tmp_outfile > $tmp_logfile";
#     my $result = `$command`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    system("$command");
    $result = `cat $tmp_outfile`;
    
#     if ($stderr) {
# 	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
#     }
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    print TMP_OUT $result;
#     print TMP_OUT "KEYS ".keys(%args);
    close TMP_OUT;
    

    &UpdateLogFileWS(command=>$command,
		     tmp_outfile=>$tmp_outfile,
		     method_name=>"RNSC",
		     output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}

sub rnsc_cmd {
  my ($self, %args) =@_;
  
  my $command = "/home/rsat/rsa-tools/bin/rnsc";
  
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/rnsc-input.XXXXXXXXXX`;
   chomp $tmp_input;
   open TMP_IN, ">".$tmp_input or die "cannot open temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -g '".$tmp_input."'";
  }
  
  if ($args{max_clust}) {
   my $max_clust = $args{max_clust};
   $max_clust =~ s/\'//g;
   $max_clust =~ s/\'//g;
   $command .= " -c $max_clust";
  }
  if ($args{tabulist}) {
   my $tabulist = $args{tabulist};
   $tabulist =~ s/\'//g;
   $tabulist =~ s/\'//g;
   $command .= " -t $tabulist";
  }
  if ($args{tabulength}) {
   my $tabulength = $args{tabulength};
   $tabulength =~ s/\'//g;
   $tabulength =~ s/\'//g;
   $command .= " -T $tabulength";
  }
  if ($args{naive_stop}) {
   my $naive_stop = $args{naive_stop};
   $naive_stop =~ s/\'//g;
   $naive_stop =~ s/\'//g;
   $command .= " -n $naive_stop";
  }
  if ($args{scale_stop}) {
   my $scale_stop = $args{scale_stop};
   $scale_stop =~ s/\'//g;
   $scale_stop =~ s/\'//g;
   $command .= " -N $scale_stop";
  }
  if ($args{div_freq}) {
   my $div_freq = $args{div_freq};
   $div_freq =~ s/\'//g;
   $div_freq =~ s/\'//g;
   $command .= " -D $div_freq";
  }
  if ($args{exp_nb}) {
   my $exp_nb = $args{exp_nb};
   $exp_nb =~ s/\'//g;
   $exp_nb =~ s/\'//g;
   $command .= " -e $exp_nb";
  }
  if ($args{shf_div_len}) {
   my $shf_div_len = $args{shf_div_len};
   $shf_div_len =~ s/\'//g;
   $shf_div_len =~ s/\'//g;
   $command .= " -d $shf_div_len";
  }
  return $command;
}








##########
sub mcl {
    my ($self, $args_ref) = @_;
    my %args = %$args_ref;
    my $output_choice = $args{"output"};
    unless ($output_choice) {
	$output_choice = 'both';
    }
    
    my $command = $self->mcl_cmd(%args);
    my $tmp_outfile = `mktemp $TMP/mcl-out.XXXXXXXXXX`;
    chomp $tmp_outfile;
    $command .= "-o $tmp_outfile";
#     my $result = `$command`;
    my $stderr = `$command 2>&1 1>/dev/null`;
    system("$command");
    $result = `cat $tmp_outfile`;
    
#     if ($stderr) {
# 	die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
#     }
    open TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
    print TMP_OUT $result;
#     print TMP_OUT "KEYS ".keys(%args);
    close TMP_OUT;

    &UpdateLogFileWS(command=>$command,
		     tmp_outfile=>$tmp_outfile,
		     method_name=>$method_name,
		     output_choice=>$output_choice);

    if ($output_choice eq 'server') {
	return SOAP::Data->name('response' => {'command' => $command, 
					       'server' => $tmp_outfile});
    } elsif ($output_choice eq 'client') {
	return SOAP::Data->name('response' => {'command' => $command,
					       'client' => $result});
    } elsif ($output_choice eq 'both') {
	return SOAP::Data->name('response' => {'server' => $tmp_outfile,
					       'command' => $command, 
					       'client' => $result});
    }
}

sub mcl_cmd {
  my ($self, %args) =@_;
  
  my $command = "/usr/local/bin/mcl";
  
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/mcl-input-graph.XXXXXXXXXX`;
   ## REMOVE ALL LEADING #
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   my @input_graph_cp = split("\n", $input_graph);
   foreach my $line (@input_graph_cp) {
     next if ($line =~ /^#/);
     next if ($line =~ /^;/);
     print TMP_IN $line."\n";
   }
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " '".$tmp_input."'";
  }  
  
  if ($args{inflation}) {
   my $inflation = $args{inflation};
   $inflation =~ s/\'//g;
   $inflation =~ s/\'//g;
   $command .= " -I $inflation --abc -V all ";
  }
  return $command;
}
##########
sub parse_psi_xml {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  
  my $command = "$SCRIPTS/parse-psi-xml";
  if ($args{channels}) {
   my $channelList = $args{channels};
   $channelList =~ s/\'//g;
   $channelList =~ s/\'//g;
   @channels = split ',', $channelList;
   foreach my $channel (@channels) {
     $command .= " -channel $channel";
   }
  }
  if ($args{interactor_type}) {
   my $interactor_type_list = $args{interactor_type};
   $interactor_type_list =~ s/\'//g;
   $interactor_type_list =~ s/\'//g;
   @interactor_types = split ',', $interactor_type_list;
   foreach my $interactor_type (@interactor_types) {
     $command .= " -interactor_type $interactor_type";
   }
  }
  if ($args{uth}) {
   my $uth = $args{uth};
   $uth =~ s/\'//g;
   $uth =~ s/\'//g;
   $command .= " -uth $uth";
  }
  if ($args{lth}) {
   my $lth = $args{lth};
   $lth =~ s/\'//g;
   $lth =~ s/\'//g;
   $command .= " -lth $lth";
  }
  if ($args{inputfile}) {
   my $input_graph = $args{inputfile};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/parse-psi-xml_input.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }


  &run_WS_command($command, $output_choice, "parse-psi-xml", ".tab");
}
##########
sub random_graph {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $output_choice = $args{"output"};
  unless ($output_choice) {
    $output_choice = 'both';
  }
  
  my $command = "$SCRIPTS/random-graph";
  
  if ($args{informat}) {
   my $in_format = $args{informat};
   $in_format =~ s/\'//g;
   $in_format =~ s/\'//g;
   $command .= " -in_format $in_format";
  }
  if ($args{outformat}) {
   my $out_format = $args{outformat};
   $out_format =~ s/\'//g;
   $out_format =~ s/\'//g;
   $command .= " -out_format $out_format";
  }
  if ($args{random_type}) {
   my $random_type = $args{random_type};
   $random_type =~ s/\'//g;
   $random_type =~ s/\'//g;
   $command .= " -random_type $random_type";
  }
  if ($args{edges}) {
   my $edges = $args{edges};
   $edges =~ s/\'//g;
   $edges =~ s/\'//g;
   $command .= " -edges $edges";
  }
  if ($args{nodes}) {
   my $nodes = $args{nodes};
   $nodes =~ s/\'//g;
   $nodes =~ s/\'//g;
   $command .= " -nodes $nodes";
  }
  if ($args{mean}) {
   my $mean = $args{mean};
   $mean =~ s/\'//g;
   $mean =~ s/\'//g;
   $command .= " -mean $mean";
  }
  if ($args{sd}) {
   my $sd = $args{sd};
   $sd =~ s/\'//g;
   $sd =~ s/\'//g;
   $command .= " -sd $sd";
  }
  if ($args{degree}) {
   my $degree = $args{degree};
   $degree =~ s/\'//g;
   $degree =~ s/\'//g;
   $command .= " -degree $edges";
  }
  if ($args{wcol}) {
   my $wcol = $args{wcol};
   $wcol =~ s/\'//g;
   $wcol =~ s/\'//g;
   $command .= " -wcol $wcol";
  }
  if ($args{scol}) {
   my $scol = $args{scol};
   $scol =~ s/\'//g;
   $scol =~ s/\'//g;
   $command .= " -scol $scol";
  }
  if ($args{tcol}) {
   my $tcol = $args{tcol};
   $tcol =~ s/\'//g;
   $tcol =~ s/\'//g;
   $command .= " -tcol $tcol";
  }
  if ($args{directed}) {
   my $directed = $args{directed};
   $command .= " -directed";
  }
  if ($args{no_single}) {
   my $no_single = $args{no_single};
   $command .= " -no_single";
  }
  if ($args{duplicate}) {
   my $duplicate = $args{duplicate};
   $command .= " -duplicate";
  }
  if ($args{col_conservation}) {
   my $col_conservation = $args{col_conservation};
   $command .= " -col_conservation";
  }
  if ($args{normal}) {
   my $normal = $args{normal};
   $command .= " -normal";
  }
  if ($args{inputgraph}) {
   my $input_graph = $args{inputgraph};
   chomp $input_graph;
   my $tmp_input = `mktemp $TMP/random_graph-input-graph.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open graph temp file ".$tmp_input."\n";
   print TMP_IN $input_graph;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -i '".$tmp_input."'";
  }
  if ($args{nodefile}) {
   my $nodefile = $args{nodefile};
   chomp $nodefile;
   my $tmp_input = `mktemp $TMP/random-graph-nodes.XXXXXXXXXX`;
   open TMP_IN, ">".$tmp_input or die "cannot open nodes temp file ".$tmp_input."\n";
   print TMP_IN $nodefile;
   close TMP_IN;
   $tmp_input =~ s/\'//g;
   $tmp_input =~ s/\"//g;
   chomp $tmp_input;
   $command .= " -nodefile '".$tmp_input."'";
  }
  my $extension = $args{outformat} || "tab";
  &run_WS_command($command, $output_choice, "random-graph", ".$extension");
}

################################################################
sub monitor {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $ticket = $args{"ticket"};
  $ticket =~ s/.*\.//;
  my $grep = `ps aux | grep $ticket | grep -v 'grep' | grep -v monitor`;
  if ($grep) {
      return SOAP::Data->name('response' => {'status' => 'Running'});
  } else {
      return SOAP::Data->name('response' => {'status' => 'Done'});
  }
}
################################################################
sub get_result {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $ticket = $args{"ticket"};
  my $tmp_outfile = $TMP."/".$ticket;
  my $result = '';
  open $TMP_OUT, $tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
  while (my $line = <$TMP_OUT>) {
      $result .= $line;
  }
  close $TMP_OUT;
  return SOAP::Data->name('response' => {'client' => $result,
					 'server' => $tmp_outfile});
}
################################################################
=pod

=item B<run_WS_command>

Run a command for the web services.

=cut
sub run_WS_command {
  my ($command, $output_choice, $method_name, $out_format) = @_;
  my ($TMP_OUT, $tmp_outfile) = &File::Temp::tempfile($method_name.".".XXXXXXXXXX, SUFFIX => "$out_format", DIR => $TMP);
  chomp($tmp_outfile);
  &UpdateLogFileWS(command=>$command,
		   tmp_outfile=>$tmp_outfile,
		   method_name=>$method_name,
		   output_choice=>$output_choice);
  
  if ($output_choice eq 'email') {
      ## Execute the command and send the result URL by email
      my $email_address = 'jvhelden@ulb.ac.be';
      &RSAT::TaskManager::EmailTheResult($command, $email_address, $tmp_outfile, title=>join("RSATWS", $method_name));
      return SOAP::Data->name('response' => {'command' => $command,
					     'server' => $tmp_outfile});
      
  }

  if ($output_choice eq 'ticket') {
      $command .= " -o ".$tmp_outfile;
#      my $result = `$command > $tmp_outfile &`;
      my $result = `$command > /dev/null &`;
      my $ticket = $tmp_outfile;
      $ticket =~ s/$TMP\///;
      return SOAP::Data->name('response' => \SOAP::Data->value(SOAP::Data->name('server' => $ticket),
							       SOAP::Data->name('command' => $command)))
	  ->attr({'xmlns' => ''});
  }

  ## Execute the command on the server
#  my $result = `$command`;
#  my $stderr = `$command 2>&1 1>/dev/null`;

  local(*HIS_IN, *HIS_OUT, *HIS_ERR);
  my $childpid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $command);
  my @outlines = <HIS_OUT>;    # Read till EOF.
  my @errlines = <HIS_ERR>;    # XXX: block potential if massive

  my $result = join('', @outlines);
  my $stderr;

  foreach my $errline(@errlines) {
      ## Some errors and RSAT warnings are not considered as fatal errors
      unless (($errline =~ 'Use of uninitialized value') || ($errline =~ 'WARNING') || ($errline =~ 'there is a difference in the software release')) {
	  $stderr .= $errline;
      }
      ## RSAT warnings are added at the end of results
      if ($errline =~'WARNING') {
	  $result .= $errline;
      }
  }

  close HIS_OUT;
  close HIS_ERR;

  if ($stderr) {
      die SOAP::Fault -> faultcode('Server.ExecError') -> faultstring("Execution error: $stderr\ncommand: $command");
  }

  open $TMP_OUT, ">".$tmp_outfile or die "cannot open temp file ".$tmp_outfile."\n";
  print $TMP_OUT $result;
  close $TMP_OUT;
  if ($output_choice eq 'server') {
      return SOAP::Data->name('response' => \SOAP::Data->value(SOAP::Data->name('server' => $tmp_outfile),
							       SOAP::Data->name('command' => $command)))
	  ->attr({'xmlns' => ''});
  } elsif ($output_choice eq 'client') {
      return SOAP::Data->name('response' => \SOAP::Data->value(SOAP::Data->name('command' => $command),
							       SOAP::Data->name('client' => $result)))
	  ->attr({'xmlns' => ''});
  } elsif ($output_choice eq 'both') {
      return SOAP::Data->name('response' => \SOAP::Data->value(SOAP::Data->name('server' => $tmp_outfile),
							       SOAP::Data->name('command' => $command),
							       SOAP::Data->name('client' => $result)))
	  ->attr({'xmlns' => ''});
  }
}

################################################################
## Run the command on the server and send an email when the task is done
sub email_command {

}


################################################################
=pod

=item B<UpdateLogFileWS>

Update a specific log file for the web services.

=cut
sub UpdateLogFileWS {
  my (%args) = @_; 
  my ($sec, $min, $hour,$day,$month,$year) = localtime(time);
  unless (defined($ENV{rsat_site})) {
    $ENV{rsat_site} = `hostname`;
    chomp($ENV{rsat_site});
  }
  my $log_file = join("", $RSAT, "/public_html/logs/log-file_", $ENV{rsat_site}, "_WS", sprintf("_%04d_%02d", $year+1900,$month+1));
  print "LOG ### $log_file";
  if (open LOG, ">>".$log_file) {
    #flock(LOG,2);
    $date = &RSAT::util::AlphaDate();
    $date =~ s/\n//;
    print LOG join ("\t",
                    $date,
                    $ENV{rsat_site},
                    "$ENV{'REMOTE_USER'}\@$ENV{'REMOTE_ADDR'} ($ENV{'REMOTE_HOST'})",
                    $args{method_name},
                    $args{output_choice},
#                    $user_email,
#                    $args{message},
		    $args{tmp_outfile}, #temporary for debugging
		    $args{command} # temporary for debugging
                   ), "\n";
    #flock(LOG,8);
    close LOG;
  } else {
    die "Cannot write the webservice LOG file to $log_file, check permission\n";
  }
}

1;
