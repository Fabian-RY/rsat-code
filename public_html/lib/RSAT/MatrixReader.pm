###############################################################
#
# Class MatrixReader
#
package RSAT::MatrixReader;

use RSAT::GenericObject;
use RSAT::matrix;
use RSAT::error;
use RSAT::feature;
@ISA = qw( RSAT::GenericObject );

### class attributes

=pod

=head1 NAME

RSAT::MatrixReader

=head1 DESCRIPTION

A class for reading position-specific scoring matrices from different
formats.

=cut


################################################################
## Class variables
%supported_input_format = (
			   'tab'=>1,
			   'cb'=>1,
			   'feature'=>1,
			   'assembly'=>1,
			   'consensus'=>1,
			   'meme'=>1,
			   'gibbs'=> 1,
			   'clustal'=>1,
			   'transfac'=>1,
			   'motifsampler'=>1,
			  );


################################################################
=pod

=item readFromFile($file, $format)

Read a matrix from a file

=cut
sub readFromFile {
    my ($file, $format, %args) = @_;
    my @matrices = ();

    if ((lc($format) eq "consensus") || ($format =~ /^wc/i)) {
	@matrices = _readFromConsensusFile($file);
    } elsif (lc($format) eq "transfac") {
	@matrices = _readFromTRANSFACFile($file);
    } elsif (lc($format) eq "assembly") {
	@matrices = _readFromAssemblyFile($file);
    } elsif (lc($format) eq "gibbs") {
	@matrices = _readFromGibbsFile($file);
    } elsif (lc($format) eq "tab") {
	@matrices = _readFromTabFile($file, %args);
    } elsif (lc($format) eq "cb") {
	@matrices = _readFromClusterBusterFile($file, %args);
    } elsif (lc($format) eq "motifsampler") {
	@matrices = _readFromMotifSamplerFile($file);
    } elsif (lc($format) eq "meme") {
	@matrices = _readFromMEMEFile($file);
    } elsif (lc($format) eq "feature") {
	@matrices = _readFromFeatureFile($file);
    } elsif (lc($format) eq "clustal") {
	@matrices = _readFromClustalFile($file);
    } else {
	&main::FatalError("&RSAT::matrix::readFromFile", "Invalid format for reading matrix\t$format");
    }

    ################################################################
    ## Check that there was at least one matrix in the file
    if (scalar(@matrices) == 0) {
      &RSAT::message::Warning("File",  $file, "does not contain any matrix in", $format , "format");
    }  else {
      &RSAT::message::Info("Read ".scalar(@matrices)." matrices from file ", $file) if ($main::verbose >= 3);
    }


    ################################################################
    ## Assign or re-assign general parameters.
    ##
    ## Depending on the input format, some of these have already been
    ## assigned from the input file but we prefer to reassign them for
    ## the sake of consistency.

    my $matrix_nb = 0;
    foreach my $matrix (@matrices) {
      ## Reassign matrix numbers
      $matrix_nb++;
      $matrix->set_parameter("matrix.nb", $matrix_nb);

      ## Check that each matrix contains at least one row and one col
      if (($matrix->nrow() > 0) && ($matrix->ncol() > 0)) {
	&RSAT::message::Info("Matrix read", 
			     "nrow = ".$matrix->nrow(),
			     "ncol = ".$matrix->ncol(),
			     "prior : ".join (" ", $matrix->getPrior()),
			    ) if ($main::verbose >= 3);

	## Count number of sites per matrix
	my $site_nb = scalar($matrix->get_attribute("sequences"));
	if ($site_nb) {
	  $matrix->set_parameter("sites", $site_nb);
	}

      } else {
	&RSAT::message::Warning("The file $file does not seem to contain a matrix in format $format. Please check the file format and contents.");
      }

      ## Replace undefined values by 0
      $matrix->treat_null_values();

    }

    return @matrices;
}

################################################################
=pod

=item _readFromTRANSFACFile($file)

Read a matrix from a TRANSFAC file. This method is called by the method 
C<readFromFile($file, "TRANSFAC")>.

=cut
sub _readFromTRANSFACFile {
  my ($file) = @_;
  &RSAT::message::Info ("Reading matrix from consensus file", $file) if ($main::verbose >= 3);

  ## open input stream
  my $in = STDIN;
  if ($file) {
    open INPUT, $file;
    $in = INPUT;
  }
  my $current_matrix_nb = 0;
  my @matrices = ();
  my $matrix;
  my $command = "";
  my $ncol = 0;
  my $transfac_consensus = "";

  my %prior = ();
  my $l = 0;
  while (<$in>) {
    $l++;
    next unless (/\S/);
    s/\r//;
    chomp();
    my $version = "";

    ## Read the command line
    if (/^VV\s+/) {
      $version = $';		# '
      &RSAT::message::Warning("TRANSFAC file version", $version);

      ## Start a new matrix (one TRANSFAC file contains several matrices)
    } elsif (/^AC\s+(\S+)/) {
      my $accession = $1;
      $current_matrix_nb++;
      $matrix = new RSAT::matrix();
      $matrix->set_parameter("program", "transfac");
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      push @matrices, $matrix;
      $matrix->set_parameter("TF_accession", $accession) if ($accession);
      $matrix->set_parameter("TF_version", $version);
      $ncol = 0;
      next;

      ## Read prior alphabet from the matrix header (P0 line)
      ## Equiprobable alphabet
    } elsif (/^P0\s+/) {
      my $header = $'; #'
      my @alphabet = split /\s+/, $header;
      foreach my $letter (@alphabet) {
	$prior{lc($letter)} = 1/scalar(@alphabet);
      }
      $matrix->setPrior(%prior);
      $matrix->setAlphabet_lc(@alphabet);

      ## Sites used to build the matrix
    } elsif (/^BS\s+/) {
      my $bs = $'; #'
      my ($site_sequence, $site_id) = split(/\s*;\s*/, $bs);
#      my $site_sequence = $1;
#      my $site_id = $2;
      if ($site_sequence) {
	$matrix->push_attribute("sequences", $site_sequence);
	if ($site_id) {
	  $matrix->push_attribute("site_ids", $site_id);
	}
      }
#      &RSAT::message::Debug("line", $l, "site", $site_sequence, $site_id, $bs) if ($main::verbose >= 0);

      ## Count column of the matrix file (row in transfac format)
    } elsif (/^(\d+)\s+/) {

      my $values = $'; #'
      my @fields = split /\s+/, $values;
      my $consensus_residue = pop @fields;
      $transfac_consensus .= $consensus_residue;
      $matrix->addColumn(@fields);
      $ncol++;
      $matrix->force_attribute("ncol", $ncol);

      ## Other matrix parameters
    } elsif (/^XX/) {
      ## field separator

    } elsif (/^ID\s+/) {
      $matrix->set_parameter("identifier", $'); #'

    } elsif (/^BF\s+/) {
      $matrix->set_parameter("binding_factor", $'); #'

    } elsif (/^SD\s+/) {
      $matrix->set_parameter("short_foactor_description", $'); #'

    } elsif (/^BA\s+/) {
      $matrix->set_parameter("statistical_basis", $'); #'

    } elsif (/^DE\s+/) {
      $matrix->set_parameter("description", $'); #'

    } elsif (/^\/\//) {
      $matrix->set_parameter("transfac_consensus", $transfac_consensus);

      ## Empty rowb
    } elsif (/^(\S\S)\s+(.*)/) {
      my $field = $1;
      my $value = $2;
      &RSAT::message::Warning("Not parsed", $field, $value) if ($main::verbose >= 3);

    } else {
      &RSAT::message::Warning("skipped invalid row", $_);
    }

  }
  close $in if ($file);

  return @matrices;

}

################################################################
=pod

=item _readFromGibbsFile($file)

Read a matrix from a gibbs file. This method is called by the method 
C<readFromFile($file, "gibbs")>.

By default, the matrix is parsed from the sites.

The variable $parse_model allows to parse the matrix model exported by
the gibbs sampler. I prefer to avoid this because this model is
exported in percentages, and with some fuzzy rounding.

=cut
sub _readFromGibbsFile {
    my ($file) = @_;

    my $parse_model = 0; ## boolean: indicates whether or not to parse matrices from motif models
    my $initial_matrices = 0;  ## boolean: indicates whether or not to export the initial matrices resulting from the optimization
    my $final_matrices = 1; ## boolean: indicates whether or not to export the final matrices

    ## open input stream
    my $in = STDIN;
    if ($file) {
	open INPUT, $file;
	$in = INPUT;
    }
    $in_matrix = 0;

    my $matrix;
    my @matrices = ();
    my @matrix = ();
    my @alphabet = ();
    my $ncol = 0;
    my $nrow = 0;
    my $m = 0;
    my $gibbs_command = "";
    my $seed;

    while (<$in>) {
      $l++;
      unless (/\S/) {
	if ($in_matrix) {
	  $in_matrix = 0;
	}
	next;
      }
      s/\r//;
      chomp();

      if (/^gibbs /) {
	$gibbs_command = $_;

      } elsif (/seed: (\S+)/) {
	$seed = $1;

      } elsif (/^\s*(\d+)\-(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s*(\S*)/) {

	unless ($in_matrix) {
	  $matrix = new RSAT::matrix();
	  $matrix->set_parameter("program", "gibbs");
	  $matrix->set_parameter("command", $gibbs_command);
	  $matrix->set_parameter("gibbs.seed", $seed);
	  push @matrices, $matrix;
	  &RSAT::message::Debug("Starting to read a matrix") if ($main::verbose >= 3);
	  $in_matrix = 1;
	  # default nucletodide alphabet
	  $matrix->setAlphabet_lc("a","c","g","t");
	  $matrix->set_attribute("nrow",4);
	}

	my $seq_nb = $1;
	my $site_nb=$2;
	my $start=$3;
	my $left_flank=$4;
	my $site_seq=$5;
	my $right_flank=$4;
	my $end=$7;
	my $score=$8; $score =~ s/\(//; $score =~ s/\)//;
	my $site_id;
	if ($score eq "") {
	  $matrix->set_parameter("gibbs.type", "initial");
	  $site_id = join ("_", $seq_nb, $site_nb, $start, $end);
	} else {
	  $matrix->set_parameter("gibbs.type", "final");
	  $site_id = join ("_", $seq_nb, $site_nb, $start, $end, $score);
	}

	$matrix->add_site(lc($site_seq), id=>$site_id, score=>1);

      } elsif ((/^Motif model/) && ($parse_model)) {
#      if (/^\s*MOTIF\s+(\S+)/) {
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "gibbs");
	$matrix->set_parameter("command", $gibbs_command);
	$matrix->set_parameter("gibbs.seed", $seed);
	push @matrices, $matrix;
	&RSAT::message::Debug("Starting to read a matrix") if ($main::verbose >= 3);
	$in_matrix = 1;
	# default nucletodide alphabet
	$matrix->setAlphabet_lc("a","c","g","t");
	next;

      } elsif (/model map = (\S+); betaprior map = (\S+)/) {
	$matrix->set_parameter("gibbs.model.map", $1);
	$matrix->set_parameter("gibbs.betaprior.map", $2);
#	&RSAT::message::Warning("gibbs matrix", $matrix,
#				"model map", $matrix->get_attribute("gibbs.model.map"),
#				"betaprior map", $matrix->get_attribute("gibbs.betaprior.map"));

      } elsif (/MAP = (\S+)/) {
	$matrix->set_parameter("gibbs.MAP", $1);

      } elsif (($in_matrix) && ($parse_model)) {
	if (/^\s*POS/) {
	  ## Header line, indicating the alphabet
	  s/\r//;
	  chomp;
	  @header = split " +";
	  @alphabet = @header[1..$#header-1];
	  $matrix->setAlphabet_lc(@alphabet);
	  &RSAT::message::Debug("Alphabet", join(":", @alphabet)) if ($main::verbose >= 5);

	} elsif (/^\s*\d+\s+/) {
	  ## Add a column to the matrix (gibbs rows correspond to our columns)
	  s/\r//;
	  chomp;
	  s/^\s+//;
	  @fields = split " +";
#	  &RSAT::message::Debug("col", $ncol, "fields", scalar(@fields), @fields) if ($main::verbose >= 10);
	  @values = @fields[1..$#header-1];
	  $nrow = scalar(@values);
	  foreach my $v (0..$#values) {
	    $values[$v] =~ s/^\.$/0/;
	    $matrix[$ncol][$v] = $values[$v];
	  }
#	  &RSAT::message::Debug("col", $ncol, "values", scalar(@values), @values) if ($main::verbose >= 10);
	  $ncol++;

	} elsif (/site/) {
	  $in_matrix = 0;
	  $matrix->force_attribute("nrow", $nrow);
	  $matrix->force_attribute("ncol", $ncol);
	  $matrix->setMatrix ($nrow, $ncol, @matrix);
	  @matrix = ();
	  $nrow = 0;
	  $ncol = 0;
	  next;
	}
      }
    }
    close $in if ($file);


    ## Delete the pre-matrices (first half of the matrices)
    unless ($initial_matrices) {
      for my $m (1..(scalar(@matrices)/2)) {
	shift @matrices;
      }
    }
    unless ($final_matrices) {
      for my $m (1..(scalar(@matrices)/2)) {
	pop @matrices;
      }
    }


    return @matrices;
}


################################################################
=pod

=item _readFromConsensusFile($file)

Read a matrix from a consensus file. This method is called by the
method C<readFromFile($file, "consensus")>.

=cut
sub _readFromConsensusFile {
  my ($file) = @_;
  &RSAT::message::Info ("Reading matrix from consensus file", $file) if ($main::verbose >= 3);
  
  #    ($in, $dir) = &main::OpenInputFile($file);
  
  ## open input stream
  my $in = STDIN;
  if ($file) {
    open INPUT, $file;
    $in = INPUT;
  }
  my $current_matrix_nb = 0;
  my @matrices = ();
  my $matrix;
  my $command = "";

  my %prior = ();
  my $l = 0;
  my $final_cycle = 0;
  while (<$in>) {
    $l++;
    next unless (/\S/);
    s/\r//;
    chomp();


    ## Read the command line
    if (/COMMAND LINE: /) {
      $command = $';		# '

    } elsif (/THE LIST OF MATRICES FROM FINAL CYCLE/) {
      $final_cycle = 1;

      ## Start a new matrix (one consensus file contains several matrices)
    } elsif ((/MATRIX\s(\d+)/) && ($final_cycle)) {
      $current_matrix_nb = $1;
      $matrix = new RSAT::matrix();
      push @matrices, $matrix;
      $matrix->set_parameter("program", "consensus");
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      $matrix->set_parameter("command", $command);
      $matrix->setPrior(%prior);
      next;

      ## Read prior frequency for one residue in the consensus header
    } elsif (/letter\s+\d+:\s+(\S+).+prior frequency =\s+(\S+)/) {
      my $letter = lc($1);
      my $prior = $2;
      &RSAT::message::Info ("Prior from consensus file", $letter, $prior) if ($main::verbose >= 3);
      $prior{$letter} = $prior;

    } elsif ($current_matrix_nb >= 1) {

      ## Matrix content (counts) for one residue
      if (/^\s*(\S+)\s+\|/) {
	my @fields = split /\s+/, $_;
	## residue associated to the row
	my $residue = lc(shift @fields);
	$residue =~ s/\s*\|//;

	## skip the | between residue and numbers
	shift @fields unless &main::IsReal($fields[0]);
	$matrix->addIndexedRow($residue, @fields);

	## Sites used to build the matrix
      } elsif (/(\d+)\|(\d+)\s*\:\s*(-){0,1}(\d+)\/(\d+)\s+(\S+)/) {
	my $site_nb = $1;
	my $site_cycle = $2;
	my $site_strand = $3;
	my $site_seq_nb = $4;
	my $site_pos = $5;
	my $site_sequence = $6;
	$matrix->push_attribute("sequences", $site_sequence);
	&RSAT::message::Debug("line", $l, "site", $site_sequence) if ($main::verbose >= 4);

	## Other matrix parameters
      } elsif (/number of sequences = (\d+)/) {
	$matrix->set_parameter("sites", $1); 
      } elsif (/unadjusted information = (\S+)/) {
	$matrix->set_parameter("cons.unadjusted.information", $1); 
      } elsif (/sample size adjusted information = (\S+)/) {
	$matrix->set_parameter("cons.adjusted.information", $1); 
      } elsif (/ln\(p\-value\) = (\S+)   p\-value = (\S+)/) {
	$matrix->set_parameter("cons.ln.Pval", $1); 
	$matrix->set_parameter("cons.P-value", $2); 
      } elsif (/ln\(e\-value\) = (\S+)   e\-value = (\S+)/) {
	$matrix->set_parameter("cons.ln.Eval", $1); 
	$matrix->set_parameter("E-value", $2); 
      } elsif (/ln\(expected frequency\) = (\S+)   expected frequency = (\S+)/) {
	$matrix->set_parameter("cons.ln.exp", $1); 
	$matrix->set_parameter("cons.exp", $2); 
      }
    }
  }

  ##Check if there was at least one matrix obtained after final cycle
  unless ($final_cycle) {
    &RSAT::message::Warning("This file does not contain the \"FINAL CYCLE\" header");
  } 
  unless (scalar(@matrices) > 0) {
    &RSAT::message::Warning("This file does not contain any final cycle matrix");
  }

  close $in if ($file);
  return @matrices;
}

################################################################
=pod

=item _readFromAssemblyFile($file)

Read a matrix from the output file of pattern-assembly. This method is
called by the method C<readFromFile($file, "assembly")>.

=cut
sub _readFromAssemblyFile {
  my ($file) = @_;
  &RSAT::message::Info ("Reading matrix from pattern-assembly file", $file) if ($main::verbose >= 3);
  
  #    ($in, $dir) = &main::OpenInputFile($file);
  
  ## open input stream
  my $in = STDIN;
  if ($file) {
    open INPUT, $file;
    $in = INPUT;
  }
  my $current_matrix_nb = 0;
  my @matrices = ();
  my $matrix;
  my $command = "";

#  my %prior = ();
  my $l = 0;
  while (my $line = <$in>) {
    $l++;
    next unless ($line =~  /\S/);
    chomp($line);

    ## Read the command line
    if ($line =~ /;assembly # (\d+)\s+seed:\s+(\S+)/) {
      $current_matrix_nb = $1;
      my $seed = $2;
      $matrix = new RSAT::matrix();
      $matrix->set_parameter("program", "pattern-assembly");
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      push @matrices, $matrix;
      $matrix->setAlphabet_lc("A","C","G","T");
      $matrix->set_attribute("nrow", 4);
      $matrix->set_parameter("asmb.seed", $seed);
      &RSAT::message::Debug("New matrix from assembly", $current_matrix_nb."/".scalar(@matrices), "seed", $seed) if ($main::verbose >= 4);

    } elsif ($line =~ /^(\S+)\t(\S+)\s+(\S+)\s+isol/) {
      $current_matrix_nb++;
      my $pattern = $1; 
      my $pattern_rc = $2; 
      my $score = $3;
      $matrix = _from_isolated($pattern, $pattern_rc, $score, @matrices);
      push @matrices, $matrix;

    } elsif ($line =~ /^(\S+)\s+(\S+)\s+isol/) {
      $current_matrix_nb++;
      my $pattern = $1; 
      my $score = $2;
      $matrix = _from_isolated($pattern, "", $score, @matrices);
      push @matrices, $matrix;


      ## Consensus from a 2-strand assembly
    } elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+best consensus/) {
      $matrix->set_attribute("consensus.assembly", $1);
      $matrix->set_attribute("consensus.assembly.rc", $2);
      $matrix->set_attribute("assembly.top.score", $3);
#      &RSAT::message::Debug("Consensus for matrix", $current_matrix_nb, $1) if ($main::verbose >= 5);

      ## Consensus from a 1-strand assembly
    } elsif ($line =~ /^(\S+)\s+(\S+)\s+best consensus/) {
      $matrix->set_attribute("consensus.assembly", $1);
      $matrix->set_attribute("assembly.top.score", $3);
#      &RSAT::message::Debug("Consensus for matrix", $current_matrix_nb, $1) if ($main::verbose >= 5);

    } elsif ($line =~ /^;/) {
      next;

      ## New site from a two-strand assembly
    } elsif ($line =~ /^(\S+)\t(\S+)\s+(\S+)/) {
      my $pattern = $1; 
      my $pattern_rc = $2;
      my $score = $3;
      my $pattern_id = $pattern."|";
      $pattern =~ s/\./n/g;
      $pattern_rc =~ s/\./n/g;
#      &RSAT::message::Debug("ASSEMBLY LINE", $l, $pattern, $pattern_rc, $score) if ($main::verbose >= 5);
      $matrix->add_site(lc($pattern), score=>$score, id=>$pattern_id, max_score=>1);

      ## New site from a single-strand assembly
    } elsif ($line =~ /^(\S+)\s+(\S+)/) {
      my $pattern = $1; 
      my $score = $2;
      $pattern =~ s/\./n/g;
#      &RSAT::message::Debug("ASSEMBLY LINE", $l, $pattern, $pattern_rc, $score) if ($main::verbose >= 5);
      $matrix->add_site(lc($pattern), score=>$score, id=>$pattern, max_score=>1);

    } else {
      &RSAT::message::Warning("&RSAT::Matrixreader::_readFromAssemblyFile", "line", $l, "not parsed", $_) if ($main::verbose >= 4);
    }
  }
  close $in if ($file);

  return @matrices;
}

################################################################
=pod

=item _from_isolated($pattern, $pattern_rc, $score, @matrices)

Create a matrix from an isolated pattern string.

=cut
sub _from_isolated {
  my ($pattern, $pattern_rc, $score, @matrices) = @_;
  my $pattern_id = $pattern;
  $pattern =~ s/\./n/g;
  if ($pattern_rc) {
    $pattern_rc =~ s/\./n/g;
    $pattern_id = $pattern."|".$pattern_rc;
  }
  $matrix = new RSAT::matrix();
  $matrix->set_parameter("program", "pattern-assembly");
  $matrix->set_parameter("matrix.nb", $current_matrix_nb);
  $matrix->setAlphabet_lc("A","C","G","T");
  $matrix->set_attribute("nrow", 4);
  $matrix->set_parameter("asmb.seed", $pattern);
  $matrix->set_attribute("asmb.consensus", $pattern);
  $matrix->set_attribute("asmb.consensus.rc", $pattern_rc);
  $matrix->set_attribute("asmb..top.score", $score);
  $matrix->add_site(lc($pattern), score=>$score, id=>$pattern_id,, max_score=>1);
  &RSAT::message::Debug("New matrix from isolated pattern", $current_matrix_nb."/".scalar(@matrices), "seed", $seed) if ($main::verbose >= 4);
  return $matrix;
}

################################################################
=pod

=item _readFromTabFile($file)

Read a matrix from a tab-delimited file. This method is called by the
method C<readFromFile($file, "tab")>.

=cut
sub _readFromTabFile {
    my ($file, %args) = @_;
    &RSAT::message::Info(join("\t", "Reading matrix from tab file\t",$file)) if ($main::verbose >= 3);

    ## open input stream
    my ($in, $dir) = &main::OpenInputFile($file);
    if ($file) {
	open INPUT, $file;
	$in = INPUT;
    }


    ## read header
    if ($args{header}) {
	$header = <$in>;
	$header =~ s/\r//;
	chomp ($header);
	$header =~ s/\s+/\t/g;
	@header = split "\t", $header;
	$matrix->push_attribute("header", @header);
    }


    ## Initialize the matrix list
    my @matrices = ();
    my $matrix = new RSAT::matrix(); 
    $matrix->set_parameter("program", "tab");
    $matrix->set_parameter("matrix.nb", $current_matrix_nb);
   push @matrices, $matrix;
    my $current_matrix_nb = 1;
#    my $id = $file."_".$current_matrix_nb;
    my $id_prefix = $file || "matrix";
    my $id = $id_prefix."_".$current_matrix_nb;
    $matrix->set_attribute("AC", $id);
    $matrix->set_attribute("id", $id);
    my $l = 0;
    while ($line = <$in>) {
      $l++;
      next unless ($line =~ /\S/); ## Skip empty lines
      chomp($line); ## Suppress newline
      $line =~ s/\r//; ## Suppress carriage return
      $line =~ s/\s+/\t/g; ## Replace spaces by tabulation

      next if ($line =~ /^;/) ; # skip comment lines

#	&RSAT::message::Debug("line", $l, $line) if ($main::verbose >= 10);
	## Create a new matrix if required
	if  ($line =~ /\/\//) {
	  $matrix = new RSAT::matrix();
	  $matrix->set_parameter("program", "tab");
	  push @matrices, $matrix;
	  $current_matrix_nb++;
	  $id = $id_prefix."_".$current_matrix_nb;
	  $matrix->set_attribute("AC", $id);
	  $matrix->set_attribute("id", $id);
	  &RSAT::message::Info("line", $l, "new matrix", $current_matrix_nb) if ($main::verbose >= 5);
	  next;
	}

      if ($line =~ /^\s*(\S+)\s+/) {

	my @fields = split /\t/, $line;


	## residue associated to the row
	my $residue = lc(shift @fields);

	## skip the | between residue and numbers
	shift @fields unless &main::IsReal($fields[0]);

	$matrix->addIndexedRow($residue, @fields);
      }
    }
    close $in if ($file);


    ## Initialize prior as equiprobable alphabet
    foreach my $matrix (@matrices) {
      my @alphabet = $matrix->getAlphabet();
      my %tmp_prior = ();
      my $prior = 1/scalar(@alphabet);
      foreach my $residue (@alphabet) {
	$tmp_prior{$residue} = $prior;
	#	&RSAT::message::Debug("initial prior", $residue, $prior) if ($main::verbose >= 10);
      }
      $matrix->setPrior(%tmp_prior);
      
      if ($main::verbose >= 3) {
	&RSAT::message::Debug("Read matrix with alphabet", join(":", $matrix->getAlphabet()));
	&RSAT::message::Debug("Initialized prior as equiprobable", join(":", $matrix->getPrior()));
	&RSAT::message::Debug("Matrix size", $matrix->nrow()." rows",  $matrix->ncol()." columns");
      }
    }

    return (@matrices);
}



################################################################
=pod

=item _readFromClusterBusterFile($file)

Read a matrix from a file in ClusterBuster format (files with
extension.cb). This method is called by the method
C<readFromFile($file, "cb")>.

=cut
sub _readFromClusterBusterFile {
    my ($file, %args) = @_;
    &RSAT::message::Info(join("\t", "Reading matrix from ClusterBuster file\t",$file)) if ($main::verbose >= 3);


    ## open input stream
    my ($in, $dir) = &main::OpenInputFile($file);
    if ($file) {
	open INPUT, $file;
	$in = INPUT;
    }

    ## Initialize the matrix list
    my @matrices = ();
    my $matrix;
    my $current_matrix_nb = 1;
    my $l = 0;
    my $ncol = 0;
    while ($line = <$in>) {
      $l++;
      next unless ($line =~ /\S/); ## Skip empty lines
      chomp($line); ## Suppress newline
      $line =~ s/\r//; ## Suppress carriage return
      $line =~ s/\s+/\t/g; ## Replace spaces by tabulation
      next if ($line =~ /^;/) ; # skip comment lines
      #	&RSAT::message::Debug("line", $l, $line) if ($main::verbose >= 10);
      ## Create a new matrix if required
      if  ($line =~ /^\>(\S*)/) {
	my $name = $1;
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "clusterbuster");
	$ncol = 0;
	if ($name) {
	  $matrix->set_attribute("name", $name);
	}
	push @matrices, $matrix;
	$current_matrix_nb++;
	&RSAT::message::Info("line", $l, "new matrix", $current_matrix_nb, $name) if ($main::verbose >= 5);
	next;
      }

      if ($line =~ /^\s*(\S+)\s+/) {
	$line = &main::trim($line);
	my @fields = split /\t/, $line;
	$matrix->addColumn(@fields);
	$ncol++;
	$matrix->force_attribute("ncol", $ncol);
      }
    }
    close $in if ($file);

    ## Initialize prior as equiprobable alphabet
    foreach my $matrix (@matrices) {
      my @alphabet = qw(a c g t);
      $matrix->setAlphabet_lc(@alphabet);
      $matrix->set_attribute("nrow", 4);
      my %tmp_prior = ();
      my $prior = 1/scalar(@alphabet);
      foreach my $residue (@alphabet) {
	$tmp_prior{$residue} = $prior;
	#	&RSAT::message::Debug("initial prior", $residue, $prior) if ($main::verbose >= 10);
      }
      $matrix->setPrior(%tmp_prior);
      if ($main::verbose >= 3) {
	&RSAT::message::Debug("Read matrix with alphabet", join(":", $matrix->getAlphabet()));
	&RSAT::message::Debug("Initialized prior as equiprobable", join(":", $matrix->getPrior()));
	&RSAT::message::Debug("Matrix size", $matrix->nrow()." rows",  $matrix->ncol()." columns");
      }
    }

    return (@matrices);
}


################################################################
=pod

=item _readFromMEMEFile($file)

Read a matrix from a MEME file. This method is called by the
method C<readFromFile($file, "MEME")>.

=cut
sub _readFromMEMEFile {
  my ($file) = @_;
  &RSAT::message::Info("Reading matrix from consensus file\t", $file) if ($main::verbose >= 3);
    
  ## open input stream
  #    ($in, $dir) = &main::OpenInputFile($file);
  my $in = STDIN;
  if ($file) {
    open INPUT, $file;
    $in = INPUT;
  }
  my @matrices = ();
  my $current_matrix_nb = 0;
  my $matrix;
  my $current_col = 0;
  my $in_proba_matrix = 0;
  my $in_blocks = 0;
  my $width_to_parse = 0;
  my %alphabet = ();
  my %residue_frequencies = ();
  my @alphabet = ();
  my @frequencies = ();
#  my $parsed_width = 0;
  my $l = 0;
  my $meme_command = "";
  while (<$in>) {
    $l++;
    next unless (/\S/);
    s/\r//;
    chomp();
    $_ = &main::trim($_);
    if (/MOTIF\s+(\d+)\s+width =\s+(\d+)\s+sites =\s+(\d+)\s+llr =\s+(\d+)\s+E-value =\s+(\S+)/) {
      &RSAT::message::Debug("line", $l, "Parsing matrix parameters") if ($main::verbose >= 5);

      $current_matrix_nb = $1;
      $width_to_parse = $2;
      $matrix = new RSAT::matrix();
      $matrix->init();
      $matrix->set_parameter("program", "meme");
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      $matrix->set_attribute("ncol", $2);

      $matrix->set_parameter("command", $meme_command);
      $matrix->set_parameter("sites", $3);
      $matrix->set_parameter("meme.llr", $4);
      $matrix->set_parameter("meme.E-value", $5);
      $matrix->setPrior(%residue_frequencies);
#      &RSAT::message::Debug("line", $l, "Read letter frequencies", %residue_frequencies) if ($main::verbose >= 10);
      $matrix->setAlphabet_lc(@alphabet);
      $matrix->force_attribute("nrow", scalar(@alphabet)); ## Specify the number of rows of the matrix
      push @matrices, $matrix;

      ## Meme command
    } elsif (/^command: /) {
      $meme_command = $'; #'

    } elsif (/Background letter frequencies/) {
      my $alphabet = <$in>;
      $alphabet = lc($alphabet);
      $alphabet = &main::trim($alphabet);
      %residue_frequencies = split /\s+/, $alphabet;
      @alphabet = sort (keys %residue_frequencies);
#      &RSAT::message::Debug("line", $l, "Read letter frequencies", %residue_frequencies) if ($main::verbose >= 10);

      ## Index the alphabet
      foreach my $l (0..$#alphabet) {
	$alphabet{$alphabet[$l]} = $l;
      }

      ## Parse BLOCKS format
    } elsif (/Motif (\d+) in BLOCKS format/) {
      $current_matrix_nb = $1;
      $in_blocks = 1;
      &RSAT::message::Debug("line", $l, "Starting to parse BLOCKS format") if ($main::verbose >= 5);

    } elsif ($in_blocks) {
      if (/(\S+)\s+\(\s*\d+\)\s+(\S+)/) {
	my $seq_id = $1;
	my $seq = lc($2);
	my $seq_len =  length($seq);
	if ($seq_len > 0) {
#	  $parsed_width = &main::max($parsed_width, $seq_len);
	  $matrix->add_site(lc($seq), score=>1, id=>$seq_id, max_score=>0);
	}

      } elsif (/\/\//) {
	&RSAT::message::Debug("line", $l, "BLOCKS format parsed") if ($main::verbose >= 5);
	$in_blocks = 0;

      }
    }
  }
  close $in if ($file);

  return @matrices;
#  return $matrices[0];
}

################################################################
=pod

=item _readFromFeatureFile($file)

Read a matrix from a feature file (he input of feature-map). 

This method is called by the method C<readFromFile($file, "feature")>.

The main usage is to retrieve a collection of sites resulting from
matrix-scan, in order to build a new collection of matrices from these
sites. 

The third column of the feature file (containing the feature name) is
used as matrix name. If several feature names are present in the
feature file, several matrices are returned accordingly. The 7th
column, which contains the sequence of the feature, is used to build
the matrix (or matrices).

=cut
sub _readFromFeatureFile {
  my ($file) = @_;
  &RSAT::message::Info("Reading matrix from consensus file\t", $file) if ($main::verbose >= 3);

  ## open input stream
  #    ($in, $dir) = &main::OpenInputFile($file);
  my $in = STDIN;
  if ($file) {
    open INPUT, $file;
    $in = INPUT;
  }
  my @matrices = (); 
  my %matrices = (); ## Matrices are indexed by name
  my @alphabet =  ("A", "C", "G", "T");
  my $current_matrix_nb = 0;
  my $matrix;
  my $l = 0;
  while (my $line = <$in>) {
    $l++;
    next if ($line =~ /^;/);
    next if ($line =~ /^--/);
    next if ($line =~ /^#/);
    next unless ($line =~ /\S/);
    $line =~ s/\r//;
    chomp($line);
    my $feature = new RSAT::feature();
    $feature->parse_from_row($line, "ft");
    my $matrix_name = $feature->get_attribute("feature_name");
    my $site_sequence = $feature->get_attribute("description");
    my $site_id = join ("_", 
			$feature->get_attribute("seq_name"),
			$feature->get_attribute("feature_name"),
			$feature->get_attribute("strand"),
			$feature->get_attribute("start"),
			$feature->get_attribute("end"),
		       );
    &RSAT::message::Debug("&RSAT::MatrixReader", $matrix_name,"feature parsed", $l, $site_sequence, $site_id) if ($main::verbose >= 5);
    if (defined($matrices{$matrix_name})) {
      $matrix = $matrices{$matrix_name};
    } else {
      $current_matrix_nb++;
      $matrix = new RSAT::matrix();
      $matrix->init();
      $matrix->set_parameter("program", "feature");
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      $matrix->set_attribute("name", $matrix_name);
      $matrix->set_attribute("ncol", length($site_sequence));
#      $matrix->set_parameter("sites", $3);
#      $matrix->setPrior(%residue_frequencies);
#      &RSAT::message::Debug("line", $l, "Read letter frequencies", %residue_frequencies) if ($main::verbose >= 10);
      $matrix->setAlphabet_lc(@alphabet);
      $matrix->force_attribute("nrow", scalar(@alphabet)); ## Specify the number of rows of the matrix
      $matrices{$matrix_name} = $matrix;
      push @matrices, $matrix;
    }
    $matrix->add_site(lc($site_sequence), id=>$site_id,max_score=>0,
		      "score"=>1, ## Here we don't want to add up the scores, because we want to count the residue occurrences
		    );
  }
  close $in if ($file);
  return @matrices;
}


################################################################
=pod

=item _readFromMotifSamplerFile($file)

Read a matrix from a I<MotifSampler> B<site> file (i.e. the file
specified with the option -o of MotifSampler).

MotifSampler is part of the software suite INCLUSive
(http://homes.esat.kuleuven.be/~thijs/download.html), developed by
Gert Thijs.

MotifSampler export two files: a description of the sites (option -o)
and of the matrices (option -m). We prefer to parse the file with
sites, because it is more informatiive for the following reasons: (1)
it contains the site sequences; (2) the matrix descriptin is in
relative frequencies rather than residue occurrences, which biases the
pseudo; (3) the site file contains additional statistics (IC, CS).

This method is called by the method C<readFromFile($file,
"MotifSampler")>.

=cut
sub _readFromMotifSamplerFile {
  my ($file, %args) = @_;
  &RSAT::message::Info(join("\t", "Reading matrix from MotifSampler output file\t",$file)) 
    if ($main::verbose >= 3);

  ## open input stream
  my ($in, $dir) = &main::OpenInputFile($file);

  ## Initialize the matrix list
  my @matrices = ();
  my @alphabet = qw(a c g t);
  my %prior;
  foreach my $letter (@alphabet) {
    $prior{lc($letter)} = 1/scalar(@alphabet);
  }
  my $ncol = 0;
  my $matrix;			## the amtrix object
  while (<$in>) {
    next unless /\S/;		## Skip empty lines
    next if /^#*$/;		## Skip empty lines
    if (/^#id:\s*(.*)/i) {
      
      ## The ID row also contains the matrix parameters
      my $motif_desc = $1;
      chomp($motif_desc);
      my @fields = split(/\s+/, $motif_desc);
      my $id = shift (@fields);

      $matrix = new RSAT::matrix();
      $matrix->set_parameter("program", "MotifSampler");
      $matrix->set_parameter("id", $id);
      while (my $field = shift @fields) {
	$field =~ s/:$//;
	$value = shift @fields;
	if ($field eq "instances") {
	  $matrix->set_parameter("sites", $value);
	} else {
	  $matrix->set_parameter("MS.".$field, $value);
	}
      }
      $matrix->setAlphabet_lc(@alphabet);
      $matrix->setPrior(%prior);
      $matrix->set_attribute("nrow", 4);

      push @matrices, $matrix;
    } elsif (/^#/) {
      ## Skip comment line
      next;
    } else {
      my ($seq_id, $program, $site_type, $start, $end, $score, $strand, $frame, @the_rest) = split (/\s+/, $_);
      my $desc = join(" ", @the_rest);
      $strand =~ s/\+/D/;
      $strand =~ s/\-/R/;
      my $site_seq;
      my $site_id = join ("_", $seq_id, $start, $end, $strand, $score);
      if ($desc =~ /site\s+"(\S+)"/i) {
#	die;
	$site_seq = lc($1);
	$matrix->add_site($site_seq, id=>$site_id, score=>1, max_score=>0);
#	$ncol = &RSAT::stats::max($ncol, length($site_seq));
#	$matrix->force_attribute("ncol", $ncol);
#	$matrix->treat_null_values();
      }
#      &RSAT::message::Debug($seq_id,$site_seq, $site_id) if ($main::verbose >= 0);
    }
  }
  return (@matrices);
}

################################################################
=pod

=item _readFromMotifSamplerMatrixFile($file)

Read a matrix from a I<MotifSampler> B<matrix> file (i.e. the file
specified with the option -o of MotifSampler).

MotifSampler is part of the software suite INCLUSive
(http://homes.esat.kuleuven.be/~thijs/download.html), developed by
Gert Thijs.

MotifSampler export two files: a description of the sites (option -o)
and of the matrices (option -m). We prefer to parse the file with
sites, because it is more informatiive for the following reasons: (1)
it contains the site sequences; (2) the matrix descriptin is in
relative frequencies rather than residue occurrences, which biases the
pseudo; (3) the site file contains additional statistics (IC, CS).

This method is called by the method C<readFromFile($file,
"MotifSampler")>.

=cut

sub _readFromMotifSamplerMatrixFile {
    my ($file, %args) = @_;
    &RSAT::message::Info(join("\t", "Reading matrix from MotifSampler matrix file\t",$file)) 
      if ($main::verbose >= 3);

    ## open input stream
    my ($in, $dir) = &main::OpenInputFile($file);

    ## Initialize the matrix list
    my @matrices = ();
    my @alphabet = qw(a c g t);
    my $ncol = 0;
    my $matrix; ## the amtrix object
    while (<$in>) {
      next unless /\S/; ## Skip empty lines
      next if /^#*$/; ## Skip empty lines
      if(/^#ID\s*=\s*(\S+)/) {
	my $id = $1;
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "MotifSampler");
	$matrix->set_attribute("AC", $id);
	$matrix->set_attribute("id", $id);
	$matrix->set_attribute("nrow", 4);
	$matrix->setAlphabet_lc("a","c","g","t");
	push @matrices, $matrix;
      } elsif (/^#Score = (\S+)/i) {
	$matrix->set_parameter("MS.score", $1);
      } elsif (/^#Consensus = (\S+)/i) {
	$matrix->set_parameter("MS.consensus", $1);
	for my $i (1..$ncol) {
	  my $line = (<$in>);
	  my @values = split (/\s+/, $line);
	  $matrix->addColumn(@values);
	  $matrix->force_attribute('ncol', $i);
	}
#	$matrix->force_attribute("ncol", $ncol);
      } elsif (/^#W = (\S+)/i) {
	$ncol = $1;
      }
    }
    return (@matrices);
}




################################################################
=pod

=item _readFromClustalFile($file)

Read a matrix from a multiple alignment in clustal format (extension
 .aln).  This method is called by the method C<readFromFile($file,
 "clustal")>.

=cut
sub _readFromClustalFile {
    my ($file) = @_;

    my @matrices = ();
    my $matrix = new RSAT::matrix();
    $matrix->set_parameter("program", "clustal");
    push @matrices, $matrix;
    
    ## open input stream
    my $in = STDIN;
    if ($file) {
	open INPUT, $file;
	$in = INPUT;
    }

    ## Check the header
    my $header = <$in>;
    unless ($header =~ /clustal/i) {
	&main::Warning("This file does not contain the clustal header");
    }

    ## Read the sequences
    my %sequences = ();
    warn "; Reading sequences\n" if ($main::verbose >= 3);
    while (<$in>) {
	next unless (/\S/);
	s/\r//;
	chomp();
	if (/^\s*(\S+)\s+(.+)$/) {
	    my $seq_id = $1;
	    next if ($seq_id eq "*"); ## asterisks are used to mark conservation
	    my $new_seq = $2;
	    
	    ## index the new sequence
	    $sequences{$seq_id} .= $new_seq;
	    warn join ("\t", ";", "Sequence", $seq_id, 
		       length($new_seq), length($sequences{$seq_id}),
		       ),"\n" if ($main::verbose >= 5);
	}
    }
    
    ## Calculate count matrix
    my %matrix = ();
    my %prior = ();
    my $ncol = 0;
    my $nrow = 0;
    &RSAT::message::Info("Calculating profile matrix from sequences") if ($main::verbose >= 3);
    foreach my $seq_id (sort keys %sequences) {
	my $sequence = $sequences{$seq_id};
	$sequence =~ s/\s+//g;

	################################################################
	## Distinguish between insertions and leading/trailing gaps
	$terminal_gap_char = ".";

	## Substitute leading gaps
	if ($sequence =~ /^(\-+)/) {
	    $leading_gap_len = length($1);
	    my $leading_gap = ${terminal_gap_char}x$leading_gap_len;
	    $sequence =~ s|^(\-+)|${leading_gap}|;
	}
	## Substitute trailing gaps
	if ($sequence =~ /(\-+)$/) {
	    $trailing_gap_len = length($1);
	    my $trailing_gap = ${terminal_gap_char}x$trailing_gap_len;
	    $sequence =~ s|(\-+)$|${trailing_gap}|;
	}
	warn join ("\t",";", $seq_id,$sequence), "\n" if ($main::verbose >= 5);
	    
	$ncol = &main::max($ncol, length($sequence));
	warn join ("\t", ";", "Sequence", $seq_id, length($sequence)),"\n" if ($main::verbose >= 5);
	my @sequence = split '|', $sequence;
	foreach my $i (0..$#sequence) {
	    my $res = lc($sequence[$i]);
	    next if ($res eq "N"); ## BEWARE: THIS IS FOR DNA ONLY
#	    next if ($res eq "-");
	    next if ($res eq "."); ## leading and trailing gaps
	    next if ($res eq "*");
	    $prior{$res}++;
	    $matrix{$res}->[$i] += 1;
	}
    }
    $matrix->set_attribute("ncol", $ncol);

    ## Define prior probabilities, alphabet, and matrix size
    my @alphabet = sort keys %prior;
    my $alpha_sum = 0;
    foreach my $res (@alphabet) {
	$alpha_sum += $prior{$res};
    }
    foreach my $res (@alphabet) {
	if ($alpha_sum > 0) {
	    $prior{$res} /= $alpha_sum;
	} else {
	    $prior{$res} = 0;
	}
#	warn join "\t", $res, $alpha_sum, $prior{$res};
    }
    $matrix->setPrior(%prior);

    ## Store the matrix
    my @matrix = ();
    foreach my $r (0..$#alphabet) {
	my $res = $alphabet[$r];
	my @row = @{$matrix{$res}};
	$nrow++;
	foreach $i (0..($ncol-1)) {
	    $row[$i] = 0 unless (defined($row[$i]));
	}
	$matrix->addRow(@row);
	warn join ("\t", "Adding row", $r, $res, join ":", @row, "\n"), "\n" if ($main::verbose >= 4); 
    }
    $matrix->setAlphabet_lc(@alphabet);
    $matrix->force_attribute("ncol", $ncol);
    $matrix->force_attribute("nrow", $nrow);

    warn join ("\t", "; Matrix size",  
	       $nrow,
	       $ncol,
	       $matrix->nrow(), 
	       $matrix->ncol()), "\n" 
		  if ($main::verbose >= 3);
    close $in if ($file);

    return (@matrices);
}



################################################################
=pod

=item B<SortMatrices>

Sort matrices according to the value of some parameter.

Usage:
  my @sorted_matrices = &RSAT::MatrixReader::SortMatrices ($sort_key, $sort_order, @matrices);

Parameters
  $sort_key   a parameter whose value will determine the sorting
  $sort_order desc (descending), asc (ascending) or alpha (alphabetical)
  @matrices    a list of matrices (objects belonging to the class RSAT::matrix)

=cut
sub SortMatrices {
  my ($sort_key, $sort_order, @matrices) = @_;

  ## Check if there is at least one matrix
  if (scalar(@matrices) > 0) {
    ## Check if the first matrix has the sort key as attribute
    my $first_matrix = $matrices[0];
    if ($first_matrix->get_attribute($sort_key)) {
      &RSAT::message::Info("Sorting", scalar(@matrices), "matrices by", $sort_order, $sort_key) if ($main::verbose >= 2);

      ## Sort matrices
      if ($sort_order eq "desc") {
	&RSAT::message::Warning("Sorting matrices by descending values of", $sort_key) if ($main::verbose >= 2);
	@matrices = sort {$b->{$sort_key} <=> $a->{$sort_key}} @matrices;
      } elsif ($sort_order eq "asc") {
	&RSAT::message::Warning("Sorting matrices by ascending values of", $sort_key) if ($main::verbose >= 2);
	@matrices = sort {$a->{$sort_key} <=> $b->{$sort_key}} @matrices;
      } elsif ($sort_order eq "alpha") {
	&RSAT::message::Warning("Sorting matrices by alphabetic values of", $sort_key) if ($main::verbose >= 2);
	@matrices = sort {lc($a->{$sort_key}) cmp lc($b->{$sort_key})} @matrices;
      } else {
	&RSAT::error::FatalError($sort_order, "is not a valid sorting order. Supported: desc,asc,alpha.");
      }
    } else {
      &RSAT::message::Warning("Cannot sort matrices by", $sort_key, "because this parameter is not defined for these matrices.")
	if ($main::verbose >= 0);
    }
  }

  ## Check sorting (dbugging)
  if ($main::verbose >= 4) {
    &RSAT::message::Info("Sorted", scalar(@matrices), "matrices by", $sort_order, $sort_key);
    my $m = 0;
    foreach my $matrix (@matrices) {
      $m++;
      &RSAT::message::Debug("sorted matrix", $m, $matrix->get_attribute("id"), $sort_key, $matrix->get_attribute($sort_key));
    }
  }

  return @matrices;

}

return 1;

__END__

