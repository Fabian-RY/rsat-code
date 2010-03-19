##############################################################
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
			   'alignace'=> 1,
			   'assembly'=>1,
			   'clustal'=>1,
			   'cluster-buster'=>1,
			   'consensus'=>1,
			   'feature'=>1,
			   'gibbs'=> 1,
			   'infogibbs'=>1,
			   'jaspar'=>1,
			   'meme'=>1,
			   'motifsampler'=>1,
			   'tab'=>1,
			   'transfac'=>1,
			   'uniprobe'=>1,
			  );
$supported_input_formats = join ",", keys %supported_input_formats;

################################################################
=pod

=item readFromFile($file, $format)

Read a matrix from a file.

Supported arguments.

=over

=item  top=>X

Only return the X top matrices of the file.

Example: 
 my @matrices =
    &RSAT::MatrixReader::readFromFile($matrix_file, $input_format, top=>3);

=item Other arguments

Other arguments are passed to some format-specific readers (tab,
cluster-buster).

=back

=cut
sub readFromFile {
    my ($file, $format, %args) = @_;

    my @matrices = ();

    if ((lc($format) eq "consensus") || ($format =~ /^wc/i)) {
	@matrices = _readFromConsensusFile($file);
    } elsif (lc($format) eq "transfac") {
	@matrices = _readFromTRANSFACFile($file);
    } elsif (lc($format) eq "infogibbs") {
	@matrices = _readFromInfoGibbsFile($file);
    } elsif (lc($format) eq "assembly") {
	@matrices = _readFromAssemblyFile($file);
    } elsif (lc($format) eq "gibbs") {
	@matrices = _readFromGibbsFile($file);
    } elsif (lc($format) eq "alignace") {
	@matrices = _readFromAlignACEFile($file);
    } elsif (lc($format) eq "tab") {
	@matrices = _readFromTabFile($file, %args);
    } elsif (lc($format) eq "cluster-buster") {
	@matrices = _readFromClusterBusterFile($file, %args);
    } elsif (lc($format) eq "jaspar") {
	@matrices = _readFromJasparFile($file, %args);
    } elsif (lc($format) eq "uniprobe") {
	@matrices = _readFromUniprobeFile($file, %args);
    } elsif (lc($format) eq "motifsampler") {
	@matrices = _readFromMotifSamplerFile($file);
    } elsif (lc($format) eq "meme") {
	@matrices = _readFromMEMEFile($file);
    } elsif (lc($format) eq "feature") {
	@matrices = _readFromFeatureFile($file);
    } else {
	&main::FatalError("&RSAT::matrix::readFromFile", "Invalid format for reading matrix\t$format");
    }

    ################################################################
    ## Check that there was at least one matrix in the file
    if (scalar(@matrices) == 0) {
      &RSAT::message::Warning("File",  $file, "does not contain any matrix in", $format , "format") if ($main::verbose >= 1);
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

      ## If a prefix is specified, use it in the name, ID and accession number
      if ($args{prefix}) {
	my $prefix = $args{prefix};
	if (scalar(@matrices) > 1) {
	  $m++;
	  $prefix .= "_m".$matrix_nb;
	}
	$matrix->force_attribute("name", $prefix);
	$matrix->force_attribute("id", $prefix);
	$matrix->force_attribute("AC", $prefix);
      }

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

      ## Compute MAP per sites
      if ((my $map = $matrix->get_attribute("MAP")) && (my $sites = $matrix->get_attribute("sites"))) {
	$matrix->set_parameter("MAP.per.site", $map/$sites);
      }
    }

    if (defined($args{top})) {
      my $top = $args{top};
      if ((&RSAT::util::IsNatural($top)) && ($top >= 1)) {
	my $matrix_nb = scalar(@matrices);
	if ($matrix_nb > $top) {
	  foreach my $m (($top+1)..$matrix_nb) {
	    pop @matrices;
	  }
	}
      }
    }
    return @matrices;
}

################################################################
=pod

=item InitializeEquiPriors

Initialize prior residue frequencies as equiprobable alphabet.

=cut
sub InitializeEquiPriors {
  my @matrices = @_;
  foreach my $matrix (@matrices) {
    my @alphabet = $matrix->getAlphabet();
#    my @alphabet = qw(a c g t);
    $matrix->setAlphabet_lc(@alphabet);
    $matrix->set_attribute("nrow", scalar(@alphabet));
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
}


################################################################
## read matrices from matrix file list paths

sub readMatrixFileList {
    my ($mlist, $input_dir,$input_format) = @_;
    my @matrix_files = ();
    my @matrices = ();
    while (<$mlist>) {
	next if (/'^;'/);		# skip comment lines
	next if (/'^#'/);		# skip header lines
	next if (/'^--'/);	# skip mysql-type comment lines
	next unless (/\S/);	# skip empty lines
	my @fields = split /\s+/;
	my $matrix_file = $fields[0];
	push @matrix_files, $matrix_file;

    }
    close $mlist;
    &RSAT::message::Info("Read matrix list from file", $main::infile{mlist2}, scalar(@matrix_files), "matrices") 
      if ($main::verbose >= 2);

    if (scalar(@matrix_files >= 1)) {
      foreach my $matrix_file (@matrix_files) {
	my @matrices_from_file = &readFromFile($matrix_file, $input_format);
	foreach my $matrix (@matrices_from_file) {
	  my ($matrix_name) = &RSAT::util::ShortFileName($matrix_file);
	  $matrix_name =~ s/\.\w+$//; ## suppress the extension from the file name
	  unless (defined($matrix->get_attribute("name"))){
	    $matrix->set_attribute("name", $matrix_name);
	  }
	  push @matrices, $matrix;
	}
      }
    }else{
	&RSAT::error::FatalError("The matrix ist must contain at least one matrix file path."); 
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
  &RSAT::message::Info ("Reading matrix from TRANSFAC file", $file) if ($main::verbose >= 3);

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
    next if (/^;/);
    s/\r//;
    chomp();
    my $version = "";

    ## Read the command line
    if (/^VV\s+/) {
      $version = $';		# '
      &RSAT::message::Warning("TRANSFAC file version", $version);

      ## empty field separator
    } elsif (/^XX/) {

      ## Start a new matrix (one TRANSFAC file contains several matrices)
    } elsif (/^AC\s+(\S+)/) {
      my $accession = $1;
      &RSAT::message::Info("TRANSFAC accession number", $accession) if ($main::verbose >= 3);
      $current_matrix_nb++;
      $transfac_consensus = "";
      $matrix = new RSAT::matrix();
      $matrix->set_parameter("program", "transfac");
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      push @matrices, $matrix;
      if ($accession) {
	$matrix->set_parameter("accession", $accession);
	$matrix->set_parameter("AC", $accession);
      }
      $matrix->set_parameter("version", $version);
      $ncol = 0;
#      next;

      ## Read prior alphabet from the matrix header (P0 line)
      ## Equiprobable alphabet

    } elsif ((/^PO\s+/)  || (/^P0\s+/)) { ## 2009/11/03 JvH fixed a bug, in previous versions I used P0 (zero) instead of PO (big "o")
      my $header = $'; #'
      $header = RSAT::util::trim($header);

      ## Alphabet is parsed from the TRANSFAC matrix header (P0 row)
      my @alphabet = split /\s+/, $header;
      $matrix->setAlphabet_lc(@alphabet);
      &RSAT::message::Debug("Alphabet", join(";",@alphabet)) if ($main::verbose >= 3);

      ## Check that prior has been specified
      unless ($matrix->get_attribute("prior_specified")) {
	foreach my $letter (@alphabet) {
	  $prior{lc($letter)} = 1/scalar(@alphabet) 
	    unless (defined($prior{$letter}));;
	}
	$matrix->setPrior(%prior);
      }

      ## Other matrix parameters

    } elsif ($matrix) {
      ## Sites used to build the matrix
      if (/^BS\s+/) {
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
	&RSAT::message::Info("TRANSFAC site", $site_id, $site_sequence) if ($main::verbose >= 3);
#      &RSAT::message::Debug("line", $l, "site", $site_sequence, $site_id, $bs) if ($main::verbose >= 10);

      ## Count column of the matrix file (row in TRANSFAC format)
      } elsif (/^(\d+)\s+/) {
	my $values = $'; #'
	$values = &RSAT::util::trim($values);
	my @fields = split /\s+/, $values;
	my $consensus_residue= "";
	if ($fields[$#fields] =~ /[A-Z]/i) {
	  $consensus_residue = pop @fields;
	  $transfac_consensus .= $consensus_residue;
	}
	&RSAT::message::Debug("line ".$l, "adding column", join (":", @fields)) if ($main::verbose >= 5);
	$matrix->addColumn(@fields);
	$ncol++;
	$matrix->force_attribute("ncol", $ncol);

	## Matrix identifier
      } elsif (/^ID\s+/) {
	$matrix->set_parameter("identifier", $'); #'

	## Automatically set matrix name
	if ($matrix->get_attribute("accession") eq $matrix->get_attribute("identifier")) {
	  $matrix->force_attribute("name", $matrix->get_attribute("accession"));
	}  else {
	  $matrix->force_attribute("name", join("_",
						$matrix->get_attribute("accession"),
						$matrix->get_attribute("identifier"),
					       ));
	}
	&RSAT::message::Info("TRANSFAC identifier", 
			     $matrix->get_attribute("accession"),
			     $matrix->get_attribute("identifier"),
			     $matrix->get_attribute("name")
			    ) if ($main::verbose >= 3);

	## Bound factor
      } elsif (/^BF\s+/) {
	my $factor_description = $';
	my $factor_id = "";
	$matrix->push_attribute("binding_factor_desc", $factor_description); #'
	if ($factor_description =~ /^(T\d+)/) {
	  $factor_id = $1;
	  $matrix->push_attribute("binding_factor", $factor_id); #'
	}
	&RSAT::message::Info("TRANSFAC binding factor", $factor_id, $factor_description) if ($main::verbose >= 3);
	$matrix->set_parameter("binding_factors", join(";", $matrix->get_attribute("binding_factor")));
	&RSAT::message::Info("TRANSFAC binding factors", $matrix->get_attribute("binding_factors")) if ($main::verbose >= 3);

	## Short factor description
      } elsif (/^SD\s+/) {
	$matrix->push_attribute("short_foactor_description", $'); #'
	&RSAT::message::Info("TRANSFAC short factor desc", $factor_id, $factor_description) if ($main::verbose >= 3);

	## Statistical basis
      } elsif (/^BA\s+/) {
	$matrix->set_parameter("statistical_basis", $'); #'

	## Matrix description
      } elsif (/^DE\s+/) {
	$matrix->set_parameter("description", $'); #'

	## Store the consensus at the end of the matrix
      } elsif (/^\/\//) {
	$matrix->set_parameter("transfac_consensus", $transfac_consensus);

	## Row containing other field
      } elsif (/^(\S\S)\s+(.*)/) {
	my $field = $1;
	my $value = $2;
	&RSAT::message::Warning("Not parsed", $field, $value) if ($main::verbose >= 3);

      } else {
	&RSAT::message::Warning("Skipped invalid row", $_);
      }
    }
  }
  close $in if ($file);

  return @matrices;

}



################################################################
=pod

=item _readFromInfoGibbsFile($file)

Read a matrix from a result file from I<info-gibbs> (implementation by
Matthieu Defrance, 2008). This method is called by the method
C<readFromFile($file, "InfoGibbs")>.

=cut
sub _readFromInfoGibbsFile {
    my ($file, %args) = @_;
    &RSAT::message::Info ("Reading matrices from info-gibbs file", $file) if ($main::verbose >= 3);

#  return _readFromTabFile($file);

 
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

    ################################################################
    ## Initialize the matrix list
    my @matrices = ();
    my $matrix = new RSAT::matrix();
    $matrix->set_parameter("program", "infogibbs");
    $matrix->set_parameter("matrix.nb", $current_matrix_nb);
    push @matrices, $matrix;
    my $current_matrix_nb = 1;
    #    my $id = $file."_".$current_matrix_nb;
    my $id_prefix = $file || "matrix";
    my $id = $id_prefix."_".$current_matrix_nb;
    $matrix->set_attribute("AC", $id);
    $matrix->set_attribute("id", $id);
    my $l = 0;
    my $matrix_found = 0;
    my $new_matrix = 0;
    my $no_motif = 1;
    my $read_seqs=0;
    while ($line = <$in>) {
      $l++;
      next unless ($line =~ /\S/); ## Skip empty lines
      chomp($line); ## Suppress newline
      $line =~ s/\r//; ## Suppress carriage return
      $line =~ s/(^.)\|/$1\t\|/; ## Add missing tab after residue
      
      $line_aux=$line;
      @aux_line=split (/ +/,$line_aux);

      if ($line =~ /^; random see/ ) {
	  $matrix->force_attribute("random_seed", pop (@aux_line) );
	  next;
      }
      elsif ($line =~ /^; number of runs/ ){
	  $matrix->set_attribute("num_runs", pop (@aux_line) );
	  next;
      }          
      elsif ($line =~ /^; number of iterations/){
	  $matrix->set_attribute("num_iterations", pop (@aux_line) ) ;
	  next;
      }
      elsif ($line =~ /^; sequences/){
	  $matrix->set_attribute("nb_seq" , pop (@aux_line) );  
	  next;
      }
      elsif ($line =~ /^; total size in bp/){
	  $matrix->set_attribute("total_size_bp",  pop (@aux_line) ) ;
	  next;
      }
      elsif ($line =~ /^; expected motif occurrences/){
	  $matrix->set_attribute("exp_motif_occ",  pop (@aux_line) ) ;  
	  next;
      }elsif ($line =~ /^; avg.llr/){
	  $matrix->set_attribute("avg_llr", pop (@aux_line) ) ;  
	  next;
      }elsif ($line =~ /^; avg.ic/){
	  $matrix->set_attribute("avg_ic",  pop (@aux_line) ) ;  
	  next;
      } 
      elsif ($line =~ /^; log likelihood ratio/){
	  $matrix->set_attribute("llr",  pop (@aux_line) ) ;  
	  next;
      } 
      elsif ($line =~ /^; information content/){
	  $matrix->set_attribute("ic",  pop (@aux_line) ) ;  
	  next;
      }
      elsif ($line =~ /^; seq/ ) {
      	  $no_motif = 0;
      }
      elsif( ($line =~ /^;.+-i/) ){
	  $line =~ s/; //;
	  $matrix->set_attribute("command", $line );
	  next;
      }
      
      
      if ($line =~ /^; seq	strand	pos	site/ ){
	  &RSAT::message::Info("Reading sequences from infogibbs ") if ($main::verbose >= 5);
	  $read_seqs=1; 
	 # $no_motif = 0;0
	#  <STDIN>;
	  next;
      }
      
      next if ( ($line =~ /^;/) && ($no_motif)) ; # skip comment lines
      
      if ($read_seqs && ($line =~ /^; \d/) ){
	  $line =~ s/\s+/\t/g; ## Replace spaces by tabulation
	  #print $line."\n";
	  local @fields2 = split /\t/, $line;
	  local $site_sequence= $fields2[4];	  
	  $matrix->push_attribute("sequences", $site_sequence);
	  &RSAT::message::Debug("site", $site_sequence) if ($main::verbose >= 5);
	 # <STDIN>;
	  next;
      }
      else {
	  $no_motif=1;
      }
      $line =~ s/\s+/\t/g; ## Replace spaces by tabulation
      $line =~ s/\[//g; ## Suppress [ and ] (present in the tab format of Jaspar and Pazar databases)
      $line =~ s/\]//g; ## Suppress [ and ] (present in the tab format of Jaspar and Pazar databases)
      $line =~ s/://g; ## Suppress : (present in the tab format of Uniprobe databases)
      #die $line;
      ## Create a new matrix if required
      if  ($line =~ /^\/\//) {
      	$new_matrix = 0; # tgis is to track the end of file...
	$no_motif=1;
	$read_seqs=0;
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "tab");
	push @matrices, $matrix;
	$current_matrix_nb++;
	$id = $id_prefix."_".$current_matrix_nb;
	$matrix->set_attribute("AC", $id);
	$matrix->set_attribute("id", $id);
	&RSAT::message::Info("line", $l, "new matrix", $current_matrix_nb) if ($main::verbose >= 0);
	next;
      }

      if ($line =~ /^\s*(\S+)\s+/) {
	  next if ($line =~ /^;/);
	  $new_matrix = 1;
	  $matrix_found = 1; ## There is at least one matrix row in the file
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
    if ($matrix_found) {
      if ($new_matrix == 0) {
	# eliminate empty matrix at the end
	pop(@matrices);
	$current_matrix_nb--;
      }
      &InitializeEquiPriors(@matrices);

#       foreach my $matrix (@matrices) {
# 	my @alphabet = $matrix->getAlphabet();
# 	my %tmp_prior = ();
# 	my $prior = 1/scalar(@alphabet);
# 	foreach my $residue (@alphabet) {
# 	  $tmp_prior{$residue} = $prior;
# 	  #	&RSAT::message::Debug("initial prior", $residue, $prior) if ($main::verbose >= 10);
# 	}
# 	$matrix->setPrior(%tmp_prior);
# 	if ($main::verbose >= 3) {
# 	  &RSAT::message::Debug("Read matrix with alphabet", join(":", $matrix->getAlphabet()));
# 	  &RSAT::message::Debug("Initialized prior as equiprobable", join(":", $matrix->getPrior()));
# 	  &RSAT::message::Debug("Matrix size", $matrix->nrow()." rows",  $matrix->ncol()." columns");
# 	}
#       }
    } else {
      @matrices = ();
    }

    return (@matrices);
}

################################################################
=pod

=item _readFromOldInfoGibbsFile($file)

Read a matrix from a result file from InfoGibbs (implementation by
Gregory Gathy, 2007). This method is called by the method
C<readFromFile($file, "InfoGibbs")>.

This format was a customized version of the TRANSFAC format, developed
for the Master thesis of Gregory Gathy. The program is not supported
anymore, it has been replaced by Matthieu Defrance's implementation
I<info-gibbs>.

=cut
sub _readFromOldInfoGibbsFile {
  my ($file) = @_;
  &RSAT::message::Info ("Reading matrices from InfoGibbs file", $file) if ($main::verbose >= 3);

  ## open input stream
  my ($in, $dir) = &main::OpenInputFile($file);
#  my ($in) = STDIN;
#  if ($file) {
#    open INPUT, $file;
#    $in = INPUT;
#  }
  my $current_matrix_nb = 0;
  my @matrices = ();
  my $matrix;
  my $version = "";
  my $command = "";
  my $ncol = 0;
  my $infogibbs_consensus = "";
  my %select_type = ("final"=>1);

  my %prior = ();
  my $l = 0;
  while (<$in>) {
    $l++;
    chomp();

#    &RSAT::message::Debug($l, $_) if ($main::verbose >= 10);
    next unless (/\S/);
    s/\r//;
    my $version = "";

    ## Read the command line
    if (/^VV\s+/) {
      ## InfoGibbs version
      $version = $';		# '
      &RSAT::message::Info("InfoGibbs version", $version) if ($main::verbose >= 3);

    } elsif (/^CM\s+/) {
      ## InfoGibbs command
      $command = $';		# '
      &RSAT::message::Info("InfoGibbs command", $command) if ($main::verbose >= 3);

    } elsif (/^PR\s+/) {
      my $prior_error = 0;
      ## InfoGibbs command
      my $prior_line = $';		# '
      my @fields = split /;\s*/, $prior_line;
      my %new_prior = ();
      foreach my $field (@fields) {
	if ($field =~ /([A-Z]):(\S+)/i) {
	  my $residue = lc($1);
	  my $prior = $2;
	  if (&RSAT::util::IsReal($prior)) {
	    $new_prior{$residue} = $prior;
	  } else {
	    &RSAT::message::Warning("InfoGibbs file", "line ".$l, "Invalid prior specification", $prior_line);
	    $prior_error = 1;
	  }
	} else {
	  &RSAT::message::Warning("InfoGibbs file", "line ".$l, "Invalid prior specification", $prior_line);
	    $prior_error = 1;
	}
      }
      unless ($prior_error) {
	%prior = %new_prior;
#	&RSAT::message::Debug("New prior", join (" ", %prior)) if ($main::verbose >= 10);
      }

      ## Start a new matrix (an InfoGibbs file contains several matrices)
    } elsif (/^AC\s+(\S+)/) {
      my $accession = $1;
      &RSAT::message::Info("New matrix", $accession) if ($main::verbose >= 2);
      $current_matrix_nb++;
      $matrix = new RSAT::matrix();
      $matrix->set_parameter("accession", "IG.".$accession);
      $matrix->set_parameter("program", "InfoGibbs");
      $matrix->set_parameter("version", $version);
      $matrix->set_parameter("command", $command);
      $matrix->set_parameter("matrix.nb", $current_matrix_nb);
      if (scalar(keys(%prior)) > 0) {
	$matrix->setPrior(%prior);
#	&RSAT::message::Debug("Prior", join (" ", %prior)) if ($main::verbose >= 5);
      }
      push @matrices, $matrix;
      $ncol = 0;
      $infogibbs_consensus = "";

      &RSAT::message::Info("Parsing matrix",  $current_matrix_nb, $matrix->get_attribute("accession")) 
	if ($main::verbose >= 2);
      next;

      ## Parameters for the current matrix
    } elsif ($matrix) {

      ## Read prior alphabet from the matrix header (P0 line)
      ## Equiprobable alphabet
      if (/^P0\s+/) {
	my $header = $'; #'
	$header = &RSAT::util::trim($header);

	## Alphabet is parsed from the InfoGibbs matrix header (P0 row)
	my @alphabet = split /\s+/, $header;
	$matrix->setAlphabet_lc(@alphabet);
	## Check that prior has been specified
	unless ($matrix->get_attribute("prior_specified")) {
	  foreach my $letter (@alphabet) {
	    $prior{lc($letter)} = 1/scalar(@alphabet) 
	      unless (defined($prior{$letter}));;
	  }
	  $matrix->setPrior(%prior);
#	  &RSAT::message::Debug("Prior", join (" ", %prior)) if ($main::verbose >= 5);
	}

	## Count column of the matrix file (row in TRANSFAC/InfoGibbs format)
      } elsif (/^(\d+)\s+/) {
	my $values = $'; #'
	$values = &RSAT::util::trim($values);
	my @fields = split /\s+/, $values;
	my $consensus_residue= "";
	if ($fields[$#fields] =~ /[A-Z]/i) {
	  $consensus_residue = pop @fields;
	  $infogibbs_consensus .= $consensus_residue;
	}
	$matrix->addColumn(@fields);
	$ncol++;
	$matrix->force_attribute("ncol", $ncol);
#	&RSAT::message::Debug("line ".$l, "adding column", $ncol, "counts", join (":", @fields))
#	  if ($main::verbose >= 0);

	## Sites used to build the matrix
      } elsif (/^BS\s+/)  {
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
#	&RSAT::message::Debug("line", $l, "site", $site_sequence, $site_id, $bs) if ($main::verbose >= 0);

	## Information content computed by InfoGibbs
      } elsif (/^IC\s+/) {
	$matrix->set_parameter("IC", $'); #'

	## Consensus score computed by InfoGibbs
      } elsif (/^CS\s+/) {
	$matrix->set_parameter("CS", $'); #'

	## Log-Likelihood computed by InfoGibbs
      } elsif (/^LL\s+/) {
	$matrix->set_parameter("LL", $'); #'

	## TRANSFAC matrix parameters (not used by InfoGibbs, but maintained for compatibility)
      } elsif (/^XX/) {
	## field separator
	next;

      } elsif (/^ID\s+/) {
	$matrix->set_parameter("identifier", $'); #'

      } elsif (/^BF\s+/) {
	$matrix->set_parameter("binding_factor", $'); #'

	#    } elsif (/^SD\s+/) {
	#      $matrix->set_parameter("short_foactor_description", $'); #'

      } elsif ((/^BA\s+/)   && ($matrix)){
	$matrix->set_parameter("statistical_basis", $'); #'

      } elsif ((/^DE\s+/)   && ($matrix)){
	$matrix->set_parameter("description", $'); #'

	## Matrix type
      } elsif ((/^TY\s+/)   && ($matrix)){
	$matrix->set_parameter("type", $'); #'

      } elsif (/^\/\//) {
	if ($matrix) {
	  $matrix->set_parameter("infogibbs_consensus", $infogibbs_consensus);
	}

	## Unknown field
      } elsif (/^(\S\S)\s+(.*)/) {
	my $field = $1;
	my $value = $2;
	&RSAT::message::Warning("Unknown field, not parsed", "line ".$l, $field, $value) if ($main::verbose >= 3);

      } else {
	&RSAT::message::Warning("skipped invalid row", "line ".$l, $_);
      }
    }

  }
  close $in if ($file);

  my @selected_matrices = ();
  foreach my $matrix (@matrices) {
    my $type = $matrix->get_attribute("type");
    if (($type) && ($select_type{$type})) {
      push @selected_matrices, $matrix;
    }
  }

  return @selected_matrices;

}

################################################################
=pod

=item _readFromAlignACEFile($file)

Read a matrix from an AlignACE file. This method is called by the method 
C<readFromFile($file, "AlignACE")>.

=cut
sub _readFromAlignACEFile {
  my ($file) = @_;
  my @matrices = ();

  my ($in, $dir) = &main::OpenInputFile($file);
  my $l = 0;
  my $matrix;
  my $matrix_nb;
  my $site_nb;
  my $expect = "";
  my $gcback = 0.5;
  my $minpass = "";
  my $seed = "";
  my $numcols = "";
  my $undersample = "";
  my $oversample = "";
  my %seq_id = ();
  while (<$in>) {
    $l++;
    chomp();
    next unless (/\S/); ## Skip empty lines
    if (/^Motif (\d+)/) {
      $matrix_nb = $1;
      $site_nb = 0;
      $matrix = new RSAT::matrix();
      $matrix->set_parameter("matrix.nb", $matrix_nb);
      $matrix->set_parameter("program", "AlignACE");
      $matrix->set_parameter("command", $AlignACE_command);
      $matrix->set_parameter("program.version", $AlignACE_version);
      $matrix->set_parameter("program.release", $AlignACE_date);
      $matrix->set_parameter("seed", $seed);
      $matrix->set_parameter("alignace.minpass", $minpass);
      $matrix->set_parameter("alignace.expect", $expect);
      $matrix->set_parameter("alignace.undersample", $undersample);
      $matrix->set_parameter("alignace.oversample", $oversample);
      &RSAT::message::Info("Starting to read matrix", $matrix_nb) if ($main::verbose >= 3);
      # default nucletodide alphabet
      $matrix->setAlphabet_lc("a","c","g","t");
      my $atback = 1-$gcback;
      $matrix->setPrior(a=>$atback/2, c=>$gcback/2,t=>$atback/2, g=>$gcback/2);
      $matrix->set_attribute("nrow",4);
      push @matrices, $matrix;
      $in_matrix = 1;
    } elsif (/^AlignACE (\d+\.\d+)\s+(\S+)/) {
      $AlignACE_version = $1;
      $AlignACE_date = $2;
    } elsif (/gcback = \s+(\S+)/) {
      $gcback = $1;
    } elsif (/seed\s+=\s+(\S+)/) {
      $seed = $1;
    } elsif (/expect\s+=\s+(\S+)/) {
      $expect = $1;
    } elsif (/minpass\s+=\s+(\S+)/) {
      $minpass = $1;
    } elsif (/oversample\s+=\s+(\S+)/) {
      $oversample = $1;
    } elsif (/undersample\s+=\s+(\S+)/) {
      $undersample = $1;
    } elsif (/^AlignACE/) {
      $AlignACE_command = $_;
    } elsif (/#(\d+)\s+(\S+)/) {
      $seq_id[$1] = $2;
    } elsif ($in_matrix) {
      if (/MAP Score:\s(\S+)/i) {
	$matrix->set_parameter("MAP", $1);
      } elsif (/(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
	$site_nb++;
	my $site_seq = $1;
	my $seq_nb = $2;
	my $site_pos = $3;
	my $site_strand = $4;
	my $site_id = join ("_", "mtx".$matrix_nb, "site".$site_nb, "seq".$seq_nb, $seq_id[$seq_nb], $site_pos, $site_strand);
	$matrix->add_site(lc($site_seq), id=>$site_id, score=>1);
      }
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

      chomp();

      ## Suppress DOS-type newline characters
      s/\r//;

      ## Empty rows indicate the end of a matrix
      unless (/\S/) {
	if ($in_matrix) {
	  $in_matrix = 0;
	}
	next;
      }

      if (/^gibbs /) {
	$gibbs_command = $_;
#	&RSAT::message::Debug("line ".$l, "gibbs command", $gibbs_command) if ($main::verbose >= 0);

      } elsif (/seed: (\S+)/) {
	$seed = $1;
#	&RSAT::message::Debug("line ".$l, "seed", $seed) if ($main::verbose >= 0);

      } elsif (/^\s*(\d+)\-(\d+)\s+(\d+)\s+([a-z]*)\s+([A-Z]+)\s+([a-z]+)\s+(\d+)\s*(\S*)/) {

	if ($in_matrix) {
#	  &RSAT::message::Debug("line ".$l, "Parsing one matrix row") if ($main::verbose >= 0);
	} else {
#	  &RSAT::message::Debug("line ".$l, "Starting to read a matrix") if ($main::verbose >= 0);
	  $matrix = new RSAT::matrix();
	  $matrix->set_parameter("program", "gibbs");
	  $matrix->set_parameter("command", $gibbs_command);
	  $matrix->set_parameter("seed", $seed);
	  push @matrices, $matrix;
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
	&RSAT::message::Debug("line ".$l, "Creating a new model matrix") if ($main::verbose >= 3);
#      if (/^\s*MOTIF\s+(\S+)/) {
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "gibbs");
	$matrix->set_parameter("command", $gibbs_command);
	$matrix->set_parameter("seed", $seed);
	push @matrices, $matrix;
	&RSAT::message::Debug("Starting to read a motif") if ($main::verbose >= 3);
	$in_matrix = 1;
	# default nucletodide alphabet
	$matrix->setAlphabet_lc("a","c","g","t");
	next;

      } elsif ((/model map = (\S+); betaprior map = (\S+)/) && ($in_matrix)) {
	$matrix->set_parameter("gibbs.model.map", $1);
	$matrix->set_parameter("gibbs.betaprior.map", $2);
#	&RSAT::message::Warning("gibbs matrix", $matrix,
#				"model map", $matrix->get_attribute("gibbs.model.map"),
#				"betaprior map", $matrix->get_attribute("gibbs.betaprior.map"));

      } elsif ((/^\s*MAP = (\S+)/) && ($matrix)) {
	$matrix->set_parameter("MAP", $1);

      } elsif ((/^\s*NetMAP = (\S+)/) && ($matrix)) {
	$matrix->set_parameter("NetMAP", $1);

      } elsif ((/^\s*sites: MAP = (\S+)/) && ($matrix)) {
	$matrix->set_parameter("sites.MAP", $1);

      } elsif ((/^\s*Initial MAP = (\S+)/) && ($matrix)) {
	$matrix->set_parameter("initial.MAP", $1);

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
#    &RSAT::message::Debug("line", $l, $_) if ($main::verbose >= 5);
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


#	&RSAT::message::Debug("&_readFromConsensusFile", $residue, "alphabet", join(":", $matrix->getAlphabet()), join ", ", @fields)
#	  if ($main::verbose >= 0);

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
	$matrix->set_parameter("cons.Pval", $2); 
      } elsif (/ln\(e\-value\) = (\S+)   e\-value = (\S+)/) {
	$matrix->set_parameter("cons.ln.Eval", $1);
	$matrix->set_parameter("cons.Eval", $2); 
      } elsif (/ln\(expected frequency\) = (\S+)   expected frequency = (\S+)/) {
	$matrix->set_parameter("cons.ln.exp", $1); 
	$matrix->set_parameter("cons.exp", $2); 
      }
    }
  }

  ##Check if there was at least one matrix obtained after final cycle
  unless ($final_cycle) {
    &RSAT::message::Warning("This file does not contain the \"FINAL CYCLE\" header") if ($main::verbose >= 2);
  } 
  unless (scalar(@matrices) > 0) {
    &RSAT::message::Warning("This file does not contain any final cycle matrix") if ($main::verbose >= 2);
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
     &RSAT::message::Debug("ASSEMBLY LINE", $l, $pattern, $pattern_rc, $score) if ($main::verbose >= 5);
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

    ################################################################
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
    my $matrix_found = 0;
    my $new_matrix = 0;
    while ($line = <$in>) {
      $l++;
      next unless ($line =~ /\S/); ## Skip empty lines
      chomp($line); ## Suppress newline
      $line =~ s/\r//; ## Suppress carriage return
      $line =~ s/(^.)\|/$1\t\|/; ## Add missing tab after residue
      $line =~ s/\s+/\t/g; ## Replace spaces by tabulation
      next if ($line =~ /^;/) ; # skip comment lines
      $line =~ s/\[//g; ## Suppress [ and ] (present in the tab format of Jaspar and Pazar databases)
      $line =~ s/\]//g; ## Suppress [ and ] (present in the tab format of Jaspar and Pazar databases)
      $line =~ s/://g; ## Suppress : (present in the tab format of Uniprobe databases)

      ## Create a new matrix if required
      if  ($line =~ /\/\//) {
      	$new_matrix = 0; # tgis is to track the end of file...
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
	$new_matrix = 1;
	$matrix_found = 1; ## There is at least one matrix row in the file
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
    if ($matrix_found) {
    	if ($new_matrix == 0) {
	    # eliminate empty matrix at the end
	    pop(@matrices);
	    $current_matrix_nb--;
	}
	&InitializeEquiPriors(@matrices);
#       foreach my $matrix (@matrices) {
# 	my @alphabet = $matrix->getAlphabet();
# 	my %tmp_prior = ();
# 	my $prior = 1/scalar(@alphabet);
# 	foreach my $residue (@alphabet) {
# 	  $tmp_prior{$residue} = $prior;
# 	  #	&RSAT::message::Debug("initial prior", $residue, $prior) if ($main::verbose >= 10);
# 	}
# 	$matrix->setPrior(%tmp_prior);
# 	if ($main::verbose >= 3) {
# 	  &RSAT::message::Debug("Read matrix with alphabet", join(":", $matrix->getAlphabet()));
# 	  &RSAT::message::Debug("Initialized prior as equiprobable", join(":", $matrix->getPrior()));
# 	  &RSAT::message::Debug("Matrix size", $matrix->nrow()." rows",  $matrix->ncol()." columns");
# 	}
#     }
    } else {
      @matrices = ();
    }

    return (@matrices);
}



################################################################
=pod

=item _readFromClusterBusterFile($file)

Read a matrix from a file in ClusterBuster format (files with
extension .cb). This method is called by the method
C<readFromFile($file, "cluster-buster")>.

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
	if ($line =~ /\/name=(\S*)/) { $name = $1;}
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "clusterbuster");
	$ncol = 0;
	if ($name) {
	  $matrix->set_attribute("name", $name);
	  $matrix->set_attribute("AC", $name);
	  $matrix->set_attribute("accession", $name);
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
    &InitializeEquiPriors(@matrices);
#     foreach my $matrix (@matrices) {
#       my @alphabet = qw(a c g t);
#       $matrix->setAlphabet_lc(@alphabet);
#       $matrix->set_attribute("nrow", 4);
#       my %tmp_prior = ();
#       my $prior = 1/scalar(@alphabet);
#       foreach my $residue (@alphabet) {
# 	$tmp_prior{$residue} = $prior;
# 	#	&RSAT::message::Debug("initial prior", $residue, $prior) if ($main::verbose >= 10);
#       }
#       $matrix->setPrior(%tmp_prior);
#       if ($main::verbose >= 3) {
# 	&RSAT::message::Debug("Read matrix with alphabet", join(":", $matrix->getAlphabet()));
# 	&RSAT::message::Debug("Initialized prior as equiprobable", join(":", $matrix->getPrior()));
# 	&RSAT::message::Debug("Matrix size", $matrix->nrow()." rows",  $matrix->ncol()." columns");
#       }
#     }

    return (@matrices);
}


################################################################
=pod

=item _readFromJasparFile($file)

Read a matrix from a file in JASPAR format (files with extension
.jaspar). JASPAR is a public database of transcription factor binding
sites and motifs (http://jaspar.cgb.ki.se/).

This method is called by the method C<readFromFile($file, "jaspar")>.

=cut
sub _readFromJasparFile {
    my ($file, %args) = @_;
    &RSAT::message::Info(join("\t", "Reading matrix from JASPAR file\t",$file)) if ($main::verbose >= 3);


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
      if  ($line =~ /^\>(\S+)/) {
	my $id = $1;
	my $postmatch = $';
	my $name = $id;
	if ($postmatch =~ /\S+/) {
	  $name = &RSAT::util::trim($postmatch);
	}
#	&RSAT::message::Debug("_readFromJasparFile", $id, $name) if ($main::verbose >= 3);
	$matrix = new RSAT::matrix();
	$matrix->set_parameter("program", "jaspar");
	$ncol = 0;

	## TF name comes in principle as the second word of the matrix header
	$matrix->force_attribute("id", $name);
	## For TRANSFAC, the accession number is the real identifier, whereas the identifier is a sort of name
	$matrix->set_attribute("AC", $id);
	$matrix->set_attribute("accession", $id);
	if ($id eq $name) {
	  $matrix->set_attribute("name", $id);
	} else {
	  $matrix->set_attribute("name", $id."_".$name);
	}
	$matrix->set_attribute("description", join("", $id, " ", $name, "; from JASPAR"));
	push @matrices, $matrix;
	$current_matrix_nb++;
	&RSAT::message::Info("line", $l, "new matrix", $current_matrix_nb, $name) if ($main::verbose >= 5);
	next;
      } elsif ($line =~ /^\s*(\S+)\s+/) {
	$line = &main::trim($line);
	$line =~ s/\[//;
	$line =~ s/\]//;
	$line =~ s/\s+/\t/;
	my @fields = split /\t/, $line;
	## residue associated to the row
	my $residue = lc(shift @fields);
	$matrix->addIndexedRow($residue, @fields);
#	&RSAT::message::Debug($line, join(";", @fields)) if ($main::verbose >= 10);
      }
    }
    close $in if ($file);

    &InitializeEquiPriors(@matrices);
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
  my $nb_matrices = scalar(@matrices);

  ## Check if there is at least one matrix
  if ($nb_matrices > 0) {

    ## Check that all matrices have the sort key as attribute
    my %key_value = ();
    my $attr_not_found = 0;
    my $not_real = 0;
    foreach my $matrix (@matrices) {
      if (my $value = $matrix->get_attribute($sort_key)) {
	$key_value{$matrix} = $value;
	unless (&RSAT::util::IsReal($value)) {
	  &RSAT::message::Debug("&RSAT::MatirxReader::SortMatrices()", "matrix", $matrix->get_attribute("id"), 
				"Non-real attribute", $sort_key, "value", $value) if ($main::verbose >= 2);
	  $not_real++;
	}
      } else {
	$attr_not_found++;
      }
    }

    if ($attr_not_found > 0) {
      &RSAT::message::Warning("Cannot sort matrices by", $sort_key,
			      "because this attribute is missing in", $attr_not_found."/".$nb_matrices, "matrices")
	if ($main::verbose >= 0);
    } elsif ($not_real > 0) {
      &RSAT::message::Warning("Cannot sort matrices by", $sort_key,
			      "because this attribute has non real values in", $not_real."/".$nb_matrices, "matrices")
	if ($main::verbose >= 0);
    } else {
      #    ## Check if the first matrix has the sort key as attribute
      #    my $first_matrix = $matrices[0];
      #    if ($first_matrix->get_attribute($sort_key)) {
      &RSAT::message::Info("Sorting", $nb_matrices, "matrices by", $sort_order, $sort_key) if ($main::verbose >= 2);

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
    }
  }

  ## Check sorting (debugging)
  if ($main::verbose >= 4) {
    &RSAT::message::Info("Sorted", $nb_matrices, "matrices by", $sort_order, $sort_key);
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

