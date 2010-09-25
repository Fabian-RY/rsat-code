###############################################################
#
# Manipulation of Position-Specific Scoring Matrices (PSSM)
#
package RSAT::matrix;

#%alphabet_index = ();

require "RSA.seq.lib";
use RSAT::table;
use RSAT::stats;
use RSAT::MarkovModel;
use RSAT::SeqUtil;
use Data::Dumper;
use POSIX qw(ceil floor);

@ISA = qw( RSAT::GenericObject RSAT::table);

=pod

=head1 NAME

    RSAT::matrix

=head1 DESCRIPTION

Main class for manipuating profile matrices (also called PSSM,
Position-Specific Scoring Matrices, count matrices, position-weight
matrices).

PSSM can be used to represent the binding specificity of a
transcription factor or the conserved residues of a protein domain.

Each row of the matrix corresponds to one residue (nucleotide or
amino-acid depending on the sequence type).  Each column corresponds
to one position in the alignment.  The value within each cell
represents the frequency of each residue at each position.

This class can export PSSM  in different formats.

=head1 RETURN FIELDS FOR THE TAB FORMAT

=head2 tab

=over

=item B<counts>

Each cell of the matrix indicates the number of occurrences of the
residue at a given position of the alignment.

=item B<profile>

The matrix is printed vertically (each matrix column becomes a row in
the output text). Additional parameters (consensus, information) are
indicated besides each position, and a histogram is drawed.

=item B<crude frequencies>

Relative frequencies are calculated as the counts of residues divided
by the total count of the column.

S<Fij=Nij/SUMi(Nij)>

where

=over

=item Nij

is the absolute frequency (counts) of residue i at position j of the
alignment

=item Fij

is the relative frequency of residue i at position j of the alignment

=back

=item Pseudo-count corrected frequencies

Relative frequencies can be corrected by a pseudo-count (b) to reduce
the bias due to the small number of observations.

The pseudo-count an be shared either in an equiprobable way,

  S<F''ij=(Nij + b/A)/[SUMi(Nij)+b]>

or according to residue prior frequencies.

  S<F''ij=(Nij + b*Pi)/[SUMi(Nij)+b]>


where

=over

=item Pi

is the prior frequency for residue i

=item A

is the size of the alphabet (A=4 for DNA).

=item b

is the pseudo-count, which is "shared" between residues according to
their prior frequencies.

=back

=item weights

Weights are calculated according to the formula from Hertz (1999), as
the natural logarithm of the ratio between the relative frequency
(corrected for pseudo-counts) and the prior residue probability.

S<Wij=ln(F''ij/Pi)>

=item information

The crude information content is calculated according to the formula
from Hertz (1999).

S<Iij = Fij*ln(Fij/Pi)>

In addition, we calculate a "corrected" information content which
takes pseudo-counts into account.


S<I''ij = F''ij*ln(F''ij/Pi)>

=item P-value

The P-value indicates the probability to observe at least Nij
occurrences of a residue at a given position of the matrix. It is
calculated with the binomial formula:

    k=N.j    N.j!      k      Nij-k
Pij= SUM  ---------- Pi (1-Pi)
    k=Nij k!(N.j-k)!

where

=over

=item Nij

is the number of occurrences of residue i at position j of
the matrix.

=item N.j

is the sum of all residue occurrences at position j of the
matrix.

=item Pi

is the prior probability of residue i.

=back

=item parameters

Returns a series of parameters associated to the matrix. The list of
parameters to be exported depends on the input formats (each pattern
discovery program returns specific parameters, which are more or less
related to each others but not identical).

Some additional parameters are optionally calculated

=over

=item consensus

The degenerate consensus is calculated by collecting, at each
position, the list of residues with a positive weight. Contrarily to
most applications, this consensus is thus weighted by prior residue
frequencies: a residue with a high frequency might not be represented
in the consensus if this frequency does not significantly exceed the
expected frequency. Uppercases are used to highlight weights >= 1.

The consensus is exported as regular expression, and with the IUPAC
code for ambiguous nucleotides (http://www.chem.qmw.ac.uk/iupac/misc/naseq.html).

       	A			(Adenine)
	C			(Cytosine)
	G			(Guanine)
	T			(Thymine)
	R	= A or G        (puRines)
	Y	= C or T        (pYrimidines)
	W	= A or T        (Weak hydrogen bonding)
	S	= G or C        (Strong hydrogen bonding)
	M	= A or C        (aMino group at common position)
	K	= G or T        (Keto group at common position)
	H	= A, C or T     (not G)
	B	= G, C or T     (not A)
	V	= G, A, C       (not T)
	D	= G, A or T     (not C)
	N	= G, A, C or T  (aNy)

The strict consensus indicates, at each position, the residue with the
highest positive weight.

=item information

The total information is calculated by summing the information content
of all the cells of the matrix. This parameters is already returned by
the program consensus (Hertz), but not by other programs.

=back

=back

=head1 METHODS

=over

=cut


################################################################
## Define class variables

## output formats
%supported_output_format = ('patser'=>1,
#			    "motifsampler"=>1,
			    "jaspar"=>1,
			    "transfac"=>1,
			    "tf"=>1,
			    "stamp"=>1,
			    "tab"=>1,
			    "consensus"=>1,
			    "cluster-buster" =>1,
			    "cb" =>1,
			    "infogibbs" =>1
#			    "logo"=>1
			   );

## Separator between matrices for multi-matrix files
%matrix_terminator = ("consensus"=>"\n",
		      "tab"=>"//",
		      "patser"=>"//",
		      "tf"=>"//" ,
		      "transfac"=>"//" ,
		      "stamp"=>"\n" ,
		      "infogibbs"=>"//");


$info_log_base = exp(1);
#$info_log_base = 2;
$info_log_denominator = log($info_log_base);

################################################################

=pod

=item B<new()>

Create an empty matrix.

=cut
sub new {
    my ($class, %args) = @_;
    my $matrix = bless {
	nrow=>0,
	ncol=>0,
	%args
	}, $class;
    return $matrix;
}


################################################################

=pod

=item B<init>

Initialize the matrix.

=cut

sub init {
    my ($self) = @_;

    ## initialize the matrix
    my $nrow = $self->nrow();
    my $ncol = $self->ncol();
    warn "Initializing the matrix $nrow rows, $ncol columns\n" if ($main::verbose >= 5);
    foreach my $r (1..$nrow) {
	foreach my $c (1..$ncol) {
	    $self->setCell($r,$c,0);
	}
    }
}

################################################################

=pod

=item B<set_parameter()>

Sets an attribute and add it to the list of parameters to export.

=cut
sub set_parameter {
    my ($self, $key, $value) = @_;
    $self->force_attribute($key, $value);
    $self->push_attribute("parameters", $key);
}

################################################################

=pod

=item B<reset()>

Empty the matrix

=cut
sub reset {
    my ($self) = @_;
    warn "Resetting the matrix to empty\n" if ($main::verbose >= 5);
    undef(@{$self->{alphabet}});
    undef(@{$self->{table}});
    $self->force_attribute("nrow", 0);
    $self->force_attribute("ncol", 0);
}


################################################################

=pod

=item B<index_alphabet>

Index the alphabet in a hash table, indicating which row of the matrix
corresponds to which letter of the alphabet.

=cut
sub index_alphabet {
    my ($self) = @_;
    my @alphabet = $self->getAlphabet();
    my $row = 0;
    foreach my $letter (@alphabet) {
	$self->add_hash_attribute("alphabet_index", lc($letter), $row);
#	$alphabet_index{$letter} = $row;
#	&RSAT::message::Debug("Alphabet index", $letter, $row) if ($main::verbose >= 10);
	$row++;
    }
}


################################################################

=pod

=item getPrior()

Return prior frequencies. If these were not defined previously,
estimate them on the basis of equiprrobable residues.

=cut
sub getPrior() {
  my ($self) = @_;
  my %prior = ();
  if ($self->get_attribute("prior_specified")) {
    %prior = $self->get_attribute("prior");
  } else {
    if (scalar(keys %prior) <= 0) {
      &main::Warning( "No prior defined: using equiprobable residues") if ($main::verbose >= 4);
      my @alphabet = $self->getAlphabet();
      my $alphabet_size = scalar(@alphabet);
      foreach my $letter (@alphabet) {
	$prior{$letter} = 1/$alphabet_size;
	#		&RSAT::message::Debug("RSAT::matrix::setPrior", $letter, $prior{$letter}) if ($main::verbose >= 10);
      }
      $self->setPrior(%prior);
    }
  }
  return %prior;
}

################################################################

=pod

=item setPrior(%prior)

Specify prior frequencies. The priors are provided as a hash table,
where keys are residues and values prior probabilities.

=cut
sub setPrior {
    my ($self, %prior) = @_;

    &RSAT::message::Info (join("\t", "setPrior", join(" ", %prior))) if ($main::verbose >= 4);
    $self->set_array_attribute("prior", %prior);
    $self->force_attribute("prior_specified", 1);

#    ## Update the alphabet
#    $self->set_array_attribute("alphabet", keys(%prior));

    ## The previously calculated weights are not valid anymore
    $self->force_attribute("frequencies_specified", 0);
    $self->force_attribute("weight_specified", 0);

    ## Report the new prior
#    if ($main::verbose >= 10) {
#	%check = $self->getPrior();
#	&RSAT::message::Info (join("\t", "&RSAT::matrix::setPrior", join(" ", %prior))) if ($main::verbose >= 4);
#	foreach my $letter (sort keys %check) {
#	    warn join("\t", "; setPrior", $letter, $prior{$letter}), "\n";
#	}
#    }
}



################################################################

=pod

=item setInfoLogBase($base)

Specify the base used for computing logarithms in the information
content.

=cut
sub setInfoLogBase {
    my ($self, $info_log_base) = @_;
    unless ((&RSAT::util::IsReal($info_log_base))  && ($info_log_base >= 1)) {
      &RSAT::error::FatalError("RSAT::matrix->setInfoLogBase()", $info_log_base,
			       "iInvalid specification for the info log base",
			       "Must be a strictly real number >= 1");
    }
    $info_log_denominator = log($info_log_base);
    $self->force_attribute("info.log.base", $info_log_base);
    &RSAT::message::Info("Info log base", $self->get_attribute("info.log.base")) if ($main::verbose >= 5);
}




# ################################################################
# =pod

# =item B<CheckPrior()>

# Check if prior probabilities have neen defined, and it this is not the
# case, set it to equiprobable residues.

# Usage:
#   my %prior = $matrix->CheckPrior();

# =cut
# sub CheckPrior {
#     my ($self) = @_;
#     my %prior = $self->getPrior();
#     my @alphabet = $self->getAlphabet();

#     ## Check that the alphabet is defined
#     unless (scalar(@alphabet) > 0) {
#       &RSAT::error::FatalError("RSAT::matrix::CheckPrior()", "Cannot check prior because the alphabet is not defined");
#     }


#     ## Check that all residues have some prior
#     my $some_defined = 0;
#     my $some_undefined = 0;
#     foreach my $residue (@alphabet) {
#       if (defined($prior{$residue})) {
# 	$some_defined = 1;
#       } else {
# 	$some_undefined = 1;
#       }
#     }

#     ## Treat the result
#     if (($some_defined) && ($some_undefined)) {
#       ## Prior proba not properly defined -> simply give a warning
#       &RSAT::message::Warning("Prior frequencies are defined only for a subset of the alphabet");

#     } elsif ($some_defined == 0) {
#       ## Prior proba not defined -> set to equiprobable
#       &RSAT::message::Warning("Setting prior probabilities to equiprobable") if ($main::verbose >= 4);
#       my $equi_prior = 1/scalar(@alphabet);
#       foreach my $residue (@alphabet) {
# 	$prior{$residue} = $equi_prior;
#       }
#       $self->setPrior(%prior);
#     }
#     return $self->getPrior();
# }


################################################################
## PROBLEM ###

=pod

=item addRow(@new_row)

Add a new row to the matrix

=cut
sub addRow {
    my ($self,@new_row) = @_;

    ## Update number of rows
    my $nrow = $self->nrow()+1;
	$self->force_attribute("nrow", $nrow);
    warn ("Matrix: updating number of rows\t", $self->nrow(), "\n") if ($main::verbose >= 5);

    ## update number of colmuns
    my $row_size = scalar(@new_row);
    if ($row_size >= $self->ncol()) {
	warn ("Matrix: updating number of columns\t", $row_size, "\n") if ($main::verbose >= 5);
	$self->force_attribute("ncol", scalar(@new_row));
    }

    ## update matrix content
    for my $c (0..$#new_row) {
	${$self->{table}}[$c][$nrow-1] = $new_row[$c];
    }
}

################################################################

=pod

=item getParameters()

Return the list of parameters associated to the matrix

=cut
sub getParameters {
    my ($self) = @_;
    return @{$self->{parameters}};
}

################################################################

=pod

=item getMatrix()

Return the whole matrix as a vector

=cut
sub getMatrix {
    my ($self) = @_;
    return @{$self->{table}};
}

################################################################

=pod

=item setMatrix($nrow, $ncol, @matrix)

Specify the whole matrix

=cut
sub setMatrix {
    my ($self,$nrow, $ncol, @matrix) = @_;
    $self->force_attribute("nrow", $nrow);
    $self->force_attribute("ncol", $ncol);
    @{$self->{table}} = @matrix;
}


=pod

=item sort_rows();

Sort the rows of a matrix according to alphabetical order. This solves
incompatibilities between some matrix formats, for example consensus,
which provides the rows in the order A,T,C,G and matrix-scan-quick,
which requires A,C,G,T.

Usage: $matrix->sort_row()

=cut
sub sort_rows {
  my ($self) = @_;
  my @alphabet = $self->getAlphabet();
  my $ncol = $self->ncol();
  my $nrow = $self->nrow();

  ## Determine the column for each residue
  my @sorted_alphabet = sort @alphabet;
  foreach my $r (0..$#sorted_alphabet) {
    my $residue = $sorted_alphabet[$r];
    $order{$residue} = $r;
  }

#  &RSAT::message::Info("Sorting matrix rows", join(";", @alphabet), join(";", @sorted_alphabet)) if ($main::verbose >= 10);

  ## Get the original count matrix
  my @ori_matrix = $self->getMatrix();

  my @sorted_matrix = ();
  for my $r  (0..$#alphabet) {
    my $residue = $alphabet[$r];
    my $target_row = $order{$residue};
    for my $c (0..($ncol-1)) {
      $sorted_matrix[$c][$target_row] = $ori_matrix[$c][$r];
    }
  }
  $self->setMatrix($nrow, $ncol, @sorted_matrix);
  $self->setAlphabet_lc(@sorted_alphabet);
}


################################################################

=pod

=item toString(%args)

Return a string description of the matrix in the same format as Jerry
Hertz programs. Additional parameters are also exported as comments,
when the verbosity is > 0.

Examples:

 toString(format=>'tab', type=>parameters)

 toString(format=>'tab', type=>counts, sep=' ', col_width=4)


=over

=item format

Output matrix format.

=item all other arguments

All other arguments are passed to the appropriate method (to_tab,
to_MotifSampler, to_TRANSFAC, ...), depending on the chosen output
format.

=back

=cut
sub toString {
    my ($self, %args) = @_;
    my $output_format = $args{format} || "tab";
    $output_format =~ s|^cb$|cluster-buster|;
    $output_format =~ s|^tf$|transfac|;

    $output_format = lc($output_format);
    if (($output_format eq "tab")
	|| ($output_format eq "patser")) {
      return $self->to_tab(%args);
    } elsif ($output_format eq "jaspar") {
      return $self->to_jaspar(%args);
#    } elsif (lc($output_format) eq "motifsampler") {
#      return $self->to_Motifsampler(%args);
    } elsif ($output_format eq "transfac") {
      return $self->to_TRANSFAC(%args);
    } elsif ($output_format eq "stamp") {
      return $self->to_STAMP(%args);
     } elsif ($output_format eq "cluster-buster") {
      return $self->to_cb(%args);
    } elsif ($output_format eq "consensus") {
      return $self->to_consensus(%args);
    } elsif ($output_format eq "infogibbs") {
      return $self->to_infogibbs(%args);
    }else {
      &RSAT::error::FatalError($output_format, "Invalid output format for a matrix");
    }
}

################################################################

=pod

=item to_TRANSFAC();

Converts the matrix into a string in TRANSFAC format.

=cut
sub to_TRANSFAC {
    my ($self, %args) = @_;
    my $to_print = "";

    my $output_format = $args{format};
    $output_format = lc($output_format);

    ## Accession number
    my $accession = $self->get_attribute("accession") ||  $self->get_attribute("AC") || $self->get_attribute("name");
    if ($accession) {
      $to_print .= "AC  ".$accession."\n";
      $to_print .= "XX\n";
    }

    ## Identifier
    my $id = $self->get_attribute("identifier");
    unless ($id) {
	$id = $self->get_attribute("id");
    }
    unless ($id) {
	$id = $accession;
    }
    if ($id) {
      $to_print .= "ID  ".$id."\n";
      $to_print .= "XX\n";
    }

    ## Description
    ## If the description field is empty, use matrix consensus.
    ## Note: the DE field is necessary for the matrix-comparison
    ## program STAMP.
    my $desc = $self->get_attribute("description");
    unless ($desc) {
      $self->calcConsensus();
      $desc = $self->get_attribute("consensus.IUPAC");
    }
    $to_print .= "DE  ".$desc."\n";

    ## Header
    my $header = "PO  "; ## fixed bug in previous version, where I used P0 instead of PO
    my @alphabet = $self->getAlphabet();
    foreach my $letter (@alphabet) {
      $header .= sprintf "%6s", uc($letter);
    }
    $to_print .= $header."\n";

    ## count matrix
    my @matrix = $self->getMatrix();
    my $ncol = $self->ncol();
    my $nrow = $self->nrow();
    for my $c (1..$ncol) {
      $to_print .= sprintf "%-4d",$c;
      for my $r (1..$nrow) {
	my $occ = $matrix[$c-1][$r-1];
	$to_print .= sprintf " %5g",$occ;
      }
      $to_print .= "\n";
    }
    $to_print .= "XX\n";

    ## Sequences from which the matrix was built
    my $site_nb = scalar($self->get_attribute("sequences")) || 0;
    if ($site_nb > 0) {

      ## Print number of sequences
      $to_print .= sprintf("BA  %d sequences\n",$site_nb);
      $to_print .= "XX\n";

      ## Print sequences
      my @site_ids = $self->get_attribute("site_ids");
      my @site_seq = $self->get_attribute("sequences");
      foreach my $i (0..$#site_seq) {
	## TRANSFAC biding site description
	# BS (SITE accession no.; Start position for matrix sequence;
	#     length of sequence used; BS number of gaps inserted;
	#     strand orientation)
	my $site_id = "site_".$i;
	if (defined($side_ids[$i])) {
	  $site_id = $side_ids[$i];
	};
	my $site_seq = $site_seq[$i];
	$to_print .= sprintf("BS  %s; %s; 1; %s; 0; p\n", uc($site_seq), $site_id, length($site_seq));
      }
    }


    ## Parameters
    my @params = $self->get_attribute("parameters");
    if (scalar(@params) > 0) {
      for my $param (@params) {
	$to_print .= sprintf("CC  %s: ",$param);
	$to_print .= $self->get_attribute($param);
	$to_print .= "\n";
      }
      $to_print .= "XX\n";
    }

    ## End of record
    $to_print .=  $matrix_terminator{$output_format}."\n";
}

################################################################

=pod

=item to_STAMP();

Converts the matrix into a string in STAMP format.
STAMP is a dialect of the TRANSFAC format, with important differences:
- the fields ID and AC are absent, and the matrix ID comes in the field DE
- the header row (PO) is not supported
- the positions start at 0 instead of 1
- there is no matrix delimiter (the double slash)

=cut
sub to_STAMP {
    my ($self, %args) = @_;
    my $to_print = "";

    my $output_format = $args{format};
    $output_format = lc($output_format);

    ## Accession number
    my $accession = $self->get_attribute("accession") ||  $self->get_attribute("AC") || $self->get_attribute("name");
    if ($accession) {
      $to_print .= "XX	AC ".$accession."\n";
    }

    ## Identifier
    my $id = $self->get_attribute("identifier");
    unless ($id) {
	$id = $self->get_attribute("id");
    }
    if ($id) {
      $to_print .= "XX	ID ".$id."\n";
    }

    ## Description
    ##
    ## Note: The program STAMP uses the field DESC to store the matrix
    ## identifier/accession. We take the field AC (if detined) else
    ## the ID, else de DESC. FInally, if none of those fields is
    ## defined, we use the matrix consenssu as description.
    my $desc;
    if ($accession) {
      $desc = $accession;
    } elsif ($id)  {
      $desc = $id;
    } else {
      $desc = $self->get_attribute("description");
      unless ($desc) {
	$self->calcConsensus();
	$desc = $self->get_attribute("consensus.IUPAC");
      }
    }
    $to_print .= "DE  ".$desc."\n";

    ## count matrix
    my @matrix = $self->getMatrix();
    my $ncol = $self->ncol();
    my $nrow = $self->nrow();
    for my $c (1..$ncol) {
      $to_print .= sprintf "%-4d",$c-1;
      for my $r (1..$nrow) {
	my $occ = $matrix[$c-1][$r-1];
	$to_print .= sprintf "%6d",$occ;
      }
      $to_print .= "\n";
    }
    $to_print .= "XX\n";

    ## End of record
    $to_print .=  $matrix_terminator{$output_format}."\n";
}



################################################################

=pod

=item to_consensus(sep=>$sep, col_width=>$col_width, type=>$type, comment_char=>$comment_char)

Return a string description of the matrix in the same format as Jerry
Hertz program consensus. This includes the matrix (as the one used as
input by in patser) plus the sites (if present).

=cut
sub to_consensus {
  my ($self, %args) = @_;

  my $matrix_nb = $self->get_attribute("number") || 1;
  my $string = "";

  my @site_sequences = $self->get_attribute("sequences");
  my $nb_sites = scalar(@site_sequences);

  ## Write the header of the consensus file
  if ($matrix_nb == 1) {
    $string .= "PRIOR FREQUENCIES DETERMINED BY OBSERVED FREQUENCIES.\n";
    my %prior = $self->getPrior();
    my @alphabet = $self->getAlphabet();
    foreach my $l (1..scalar(@alphabet)) {
      my $letter = $alphabet[$l-1];
      my $prior = $prior{$letter} || $prior{uc($letter)};
      $string .= "letter   ".$l.": ".uc($letter)."  prior frequency = ".$prior."\n";
    }
    $string .= "\n";

    ## Header for the final cycle
    $string .= "THE LIST OF MATRICES FROM FINAL CYCLE\n\n";
  }

  ## Header for the matrix
  $string .= "MATRIX ".$matrix_nb."\n";
  $self->calcInformation();
  $string .= join ("", "number of sequences = ", $nb_sites || "NA", "\n");
  $string .= join ("", "unadjusted information = ",  $self->get_attribute("unadjusted.information") || $self->get_attribute("total.information") || "NA", "\n");
  $string .= join ("", "sample size adjusted information = ",  $self->get_attribute("adjusted.information") || "NA", "\n");
  $string .= join ("", "ln(p-value) = ",  $self->get_attribute("ln.Pval") || "NA",
		   "   ", "p-value = ",  $self->get_attribute("P-value") || "NA", "\n");

  ## Extract the E-value from the matrix
  my $E_value = $self->get_attribute("exp") || $self->get_attribute("E-value");
  unless (defined($E_value)) {
    $E_value = "NA";
  }

  ## Extract the ln(E-value) from the matrix or compute it from the E-value
  my $ln_E_value = "NA";
  if (defined($self->get_attribute("ln.exp"))) {
    $ln_E_value = $self->get_attribute("ln.exp")
  } elsif ($E_value eq "NA") {
    $ln_E_Value  = "NA";
  } elsif ($E_value > 0) {
    $ln_E_Value  = log($E_value);
  } else {
    $ln_E_value = "-Inf";
  }
  $string .= join ("", "ln(expected frequency) = ", $ln_E_value,
		   "   ", "expected frequency = ", $E_value , "\n");

  my $counts = $self->to_tab(type=>"counts", col_width=>4);
  $counts =~ tr/a-z/A-Z/;
  $string .= $counts;

  foreach my $s (0..$#site_sequences) {
    my $sequence = $site_sequences[$s];
    $string .= sprintf "%4d|%-4d:%5d/%-6d%s\n", $s+1, $s+1, $s+1,1, $sequence;
  }

  return $string;
}


################################################################

=pod

=item to_tab(sep=>$sep, col_width=>$col_width, type=>$type,
             comment_char=>$comment_char, no_comment=>0|1)

Return a string description of the matrix in the same format as Jerry
Hertz programs. Additional parameters are also exported as comments,
when the verbosity is > 0.

Supported parameters:

=over

=item sep

Column separator (by default, the tab character)

=item col_width

Column width (white spaces are used to ensure constant spacing)

=item comment_char

A character or string to print before each row of the matrix.

=item no_comment

Do not export the comment chars (header, margins). This is useful for
the piping buttons when the option -link is used in convert-matrix.

=back

=cut
sub to_tab {
  my ($self, %args) = @_;
  my $to_print = "";
  my $output_format = $args{format} || 'tab';
  $output_format = lc($output_format);

  ## Separator between row names (residues) and matrix content
  my $pipe =  "|";
  if (defined($args{pipe})) {
    $pipe = $args{pipe};
  }
  $self->force_attribute("pipe", $pipe);

  ## Matrix type
  $type = $args{type} || "counts";

  %supported_types = (profile=>1,
		      counts=>1,
		      countRC=>1,
		      perm_columns => 1,
		      frequencies=>1,
		      weights=>1,
		      information=>1,
		      parameters=>1,
		      consensus=>1
      );
  &main::FatalError("Invalid matrix type $type") unless $supported_types{$type};

  ## Set formatting parameters provided in arguments as matrix attribute
  foreach my $key ("sep", "col_width", "decimals") {
    if (defined($args{$key})) {
      $self->force_attribute($key, $args{$key});
    }
  }

  ## Format for the matrix entries
  my $sep = $self->get_attribute("sep") || "\t";
  my $col_width = $self->get_attribute("col_width");
  my $decimals = $self->get_attribute("decimals");

  ## Calculate number width
  my $number_width = 0;
  if ($col_width) {
    $number_width = $col_width - 1;
  }
  if ($type eq "counts") {
    $decimals = 0;
  } else {
    unless ($decimals) {
      $decimals = $number_width - 2;
    }
  }

  ################################################################
  ## Print parameters
  if ($type eq "parameters") {
    my @information = $self->getInformation();
    $to_print .= $self->_printParameters($to_print);

  } elsif ($type eq "consensus") {
    $to_print .= "; consensus\t".$self->get_attribute("consensus.IUPAC")."\n";
    $to_print .= "; consensus.rc\t".$self->get_attribute("consensus.IUPAC.rc")."\n";

    ################################################################
    ## Print a profile (vertical matrix with consensus on the right side)
  } elsif ($type eq "profile") {
    $to_print .= $self->_printProfile($to_print);

  } else {

    ################################################################
    ## Print a matrix
    my @matrix = ();
    if ($type eq "counts") {
      @matrix = @{$self->{table}};
    } else {
      @matrix = @{$self->{$type}};
    }

#    &RSAT::message::Debug("matrix to print", $self->get_attribute("id"), $type, join ", ", @matrix) if ($main::verbose >= 10);
    my @alphabet = $self->getAlphabet();
    my $ncol = $self->ncol();
    my $nrow = $self->nrow();

      ## Header of the matrix
      if (($self->get_attribute("header")) 
	  && (!$args{no_comment})){
	$to_print .= ";\n";
	$to_print .= "; Matrix type: $type\n";
	if (($col_width) && ($col_width < 6)) {
	  $to_print .= ";P";
	} else {
	  $to_print .= "; Pos";
	}
	$to_print .= $sep.$pipe if ($pipe);
	for my $c (0..($ncol-1)) {
	  my $pos = $c+1;
	  if ($col_width) {
	    $to_print .= sprintf "%${col_width}s", $pos;
	  } else {
	    $to_print .= $sep;
	    $to_print .= $pos;
	  }
	}
	$to_print .= "\n";
	$to_print .= $self->_printSeparator($ncol, $to_print);
      }

      ## Print the matrix
      for $a (0..$#alphabet) {
	my @row = &RSAT::matrix::get_row($a+1, $ncol, @matrix);
	if (defined($args{comment_char})) {
	  $to_print .= $args{comment_char};
	}
	$to_print .= $self->_printMatrixRow($alphabet[$a], @row);
      }

      ################################################################
      ##Print column statistics
      if (($self->get_attribute("margins")) 
	  && (!$args{no_comment})) {
	$prefix_letter = substr($type, 0, 1);
	$to_print .= $self->_printSeparator($ncol, $to_print);

	## Sum per column
	my @col_sum = &RSAT::matrix::col_sum($nrow, $ncol, @matrix);
	push @col_sum, &main::sum(@col_sum);
	$to_print .= $self->_printMatrixRow("; ".$prefix_letter.".sum", @col_sum);

	## Maximum per column
	my @col_max = &RSAT::matrix::col_max($nrow, $ncol, @matrix);
	push @col_max, &main::max(@col_max);
	$to_print .= $self->_printMatrixRow("; ".$prefix_letter.".max", @col_max);

	## Minimum per column
	my @col_min = &RSAT::matrix::col_min($nrow, $ncol, @matrix);
	push @col_min, &main::min(@col_min);
	$to_print .= $self->_printMatrixRow("; ".$prefix_letter.".min", @col_min);
      }
      $to_print .=  $matrix_terminator{$output_format}."\n";
    }
    return $to_print;
}

=pod

=item to_infogibbs(sep=>$sep, col_width=>$col_width, type=>$type, comment_char=>$comment_char)

Return a string description of the matrix in the same format as
Matthieu De France programs. Additional parameters are also exported
as comments, when the verbosity is > 0.

Supported parameters:

=over

=item comment_char

A character or string to print before each row of the matrix.


=item format

Output matrix format

=back

=cut
sub to_infogibbs{
    my ($self, %args) = @_;
    my $to_print = "";
    my $output_format = $args{format};
    $output_format = lc($output_format);
    $to_print .="; info-gibbs ". "\n"  ;

    my @site_sequences = $self->get_attribute("sequences");

    my $command =  $self->get_attribute("command") || "no original command available";
    my $date =$main::start_time;
    my $motif_ID =  $self->get_attribute("accession") ||  $self->get_attribute("AC") || $self->get_attribute("name");
    my $random_seed= $self->get_attribute("random_seed") || "NA";
    my $num_runs = $self->get_attribute("num_runs")|| "NA" ;
    my $num_iterations =  $self->get_attribute("num_iterations") || "NA";
    my $nb_seq = $self->get_attribute("nb_seq") ||  scalar ( @site_sequences) ||"NA" ;
    my $total_size_bp = $self->get_attribute("total_size_bp") || "NA";
    my $exp_motif_occ = $self->get_attribute("exp_motif_occ")|| $self->get_attribute("exp") || $self->get_attribute("E-value") || "NA";
    my %prior = $self->getPrior() ;

    my @alphabet = $self->getAlphabet();

    my $motif_to_find =  $self->get_attribute("motif_to_find") || "NA";
    my $avg_llr =        $self->get_attribute("avg_llr") || "NA";
    my $avg_ic  =      $self->get_attribute("avg_ic") || "NA";
    my $llr = $self->get_attribute("llr") || "NA";

    $self->calcInformation();
    my $ic  = $self->get_attribute("ic")|| $self->get_attribute("total.information")  || "NA";
    $to_print .="; ".$command ."\n";
    $to_print .="; "."title"."\n";
    $to_print .="; started at                     ". $date;
    $to_print .="; random seed                    ".  $random_seed  ."\n";
    $to_print .="; number of runs                 ".  $num_runs   ."\n";
    $to_print .="; number of iterations           ".  $num_iterations  ."\n";
    $to_print .="; sequences                      ". $nb_seq   ."\n";
    $to_print .="; total size in bp               ". $total_size_bp   ."\n";
    $to_print .="; expected motif occurrences     ". $exp_motif_occ   ."\n";

    foreach my $l (1..scalar(@alphabet)) {
      my $letter = $alphabet[$l-1];
      my $prior = $prior{$letter} || $prior{uc($letter)};
      $string_aux .= $letter.":".$prior."|";
    }
    $to_print .="; prior                          ".    $string_aux. "\n";
    $to_print .="; motifs fo find                 ". "1"    ."\n";
    $to_print .="; "."\n";
    $to_print .="; motif                          ".  $motif_ID  ."\n";
    $to_print .="; avg.llr                        ".  $avg_llr   ."\n";
    $to_print .="; avg.ic                         ". $avg_ic    ."\n";
    $to_print .="; log likelihood ratio           ".  $llr   ."\n";
    $to_print .="; information content            ". $ic   ."\n";

#    &RSAT::message::Debug("RSAT::matrix::infogibbs", $motif_ID , "++") if ($main::verbose >= 10);
  #  <STDIN>;

    ## Separator between row names (residues) and matrix content
    my $pipe =  "|";
    if (defined($args{pipe})) {
	$pipe = $args{pipe};
    }
    $self->force_attribute("pipe", $pipe);

    ## Set formatting parameters provided in arguments as matrix attribute
    foreach my $key ("sep", "col_width", "decimals") {
	if (defined($args{$key})) {
	    $self->force_attribute($key, $args{$key});
	}
    }

    ## Format for the matrix entries
    my $sep = $self->get_attribute("sep") || "\t";
    my $col_width = $self->get_attribute("col_width") || $self->ncol();;
    my $decimals = $self->get_attribute("decimals");

    ## Calculate number width
    my $number_width = 0;
    if ($col_width) {
	$number_width = $col_width - 1;
    }
    $to_print .="; motifs width                      ".  $col_width   ."\n";
    $to_print .="; sites                             ".  $nb_seq ."\n";
    $to_print .="; (seq and pos start at 1) "."\n";
    $to_print .=join ("\t","; seq", "strand","pos","site","\n");

    if (@site_sequences){
	foreach my $s (0..$#site_sequences) {
	    my $sequence = $site_sequences[$s];
	    $to_print .= sprintf "; %4d\t%5s\t%-6d\t%s\n", $s, "+", $col_width , $sequence;
	}
    }
    else {
	$to_print.=";\n";
    }

    ################################################################
    ## Print the matrix
    my @matrix = ();

    @matrix = @{$self->{table}};

    my $ncol = $self->ncol();
    my $nrow = $self->nrow();

    ## Print the matrix
    for $a (0..$#alphabet) {
	my @row = &RSAT::matrix::get_row($a+1, $ncol, @matrix);
	if (defined($args{comment_char})) {
	    $to_print .= $args{comment_char};
	}
	$to_print .= $self->_printMatrixRow(uc( $alphabet[$a]), @row) ;
    }


    ## End of record
    $to_print .=  $matrix_terminator{$output_format}."\n";

    return $to_print;
}


################################################################

=pod

=item to_jaspar()

Export a matrix in JASPAR format.


This is space-delimited format with one row per residue, one column
per position. Each matrix is preceded by a fasta-like header line
providing the ID of the matrix plus optional comments.


Example:

 >MA0001.1 AGL3
 A  [ 0  3 79 40 66 48 65 11 65  0 ]
 C  [94 75  4  3  1  2  5  2  3  3 ]
 G  [ 1  0  3  4  1  0  5  3 28 88 ]
 T  [ 2 19 11 50 29 47 22 81  1  6 ]

=back

=cut
sub to_jaspar {
  my ($self, %args) = @_;

  ## Print the header line
  my $to_print = ">";
  my $id = $self->get_attribute("id") || $self->get_attribute("identifier");
  $to_print .= $id;
  my $name = $self->get_attribute("name");
  if ($name) {
    $to_print .= " ".$name;
  }
  $to_print .= "\n";

  ## Print the matrix
  my @matrix = $self->getMatrix();
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @alphabet = $self->getAlphabet();
  my $max_count = 0;
  for my $c (1..$ncol) {
    $max_count = &RSAT::stats::max($max_count, @{$matrix[$c-1]});
  }
  my $digits = ceil(log($max_count)/log(10));
  for my $r (1..$nrow) {
    $to_print .= uc($alphabet[$r-1]);
    $to_print .= "  [";
    for my $c (1..$ncol) {
      my $value = $matrix[$c-1][$r-1];
      if (&RSAT::util::IsNatural($value)) {
	$to_print .= sprintf "%".$digits."s ", $value;
      } else {
	$to_print .= $value." ";
      }
    }
    $to_print .= "]\n";
  }
  return $to_print;
}

################################################################

=pod

=item to_cb(sep=>$sep, col_width=>$col_width, type=>$type, comment_char=>$comment_char)

Return a string description of the matrix in the same format as Cluster-Buster or TRAP (Vingron's lab).
Additional parameters are also exported as comments,when the verbosity is > 0.

Supported parameters:

=over

=item comment_char

A character or string to print before each row of the matrix.


=item format

Output matrix format

=back

=cut
sub to_cb {
  my ($self, %args) = @_;
  my $to_print = "";

  my $output_format = $args{format};
  $output_format = lc($output_format);

  ## name
  my $accession = $self->get_attribute("AC") || $self->get_attribute("accession")
    || $self->get_attribute("identifier") || $self->get_attribute("id") || $self->get_attribute("name");

  $to_print .= ">".$accession." ";

  ## other information in the header:
  #name
  my $name = $self->get_attribute("name") ||  $self->get_attribute("AC") || $self->get_attribute("accession")
    || $self->get_attribute("identifier") || $self->get_attribute("id");
  $to_print .= "/name=".$name." ";
  #information content
  my @information = $self->getInformation();
  $to_print .= "/info=".sprintf("%.3f",$self->get_attribute("total.information"))." ";
  #gc content
  $self->calcGCcontent();
  $to_print .= "/gc_content=".sprintf("%.3f",$self->get_attribute("G+C.content.crude.freq"))." ";
  #consensus
  $self->calcConsensus();
  $to_print .= "/consensus=".uc($self->get_attribute("consensus.IUPAC"))." ";
  #size
  $to_print .= "/size=".$self->get_attribute("ncol")." ";

  $to_print .= "\n";

  ## count matrix
  my @matrix = $self->getMatrix();
  my $ncol = $self->ncol();
  my $nrow = $self->nrow();
  for my $c (1..$ncol) {
    for my $r (1..$nrow) {
      my $occ = $matrix[$c-1][$r-1];
      $to_print .= $occ;
      $to_print .= "\t";
    }
    $to_print .= "\n";
  }

  ## End of record
  return $to_print;
}

################################################################

=pod

=item getWeights()

Return the weight matrix

=cut
sub getWeights {
    my ($self) = @_;
    unless ($self->get_attribute("weight_specified") >= 1) {
	$self->calcWeights();
    }
    return @{$self->{weights}};
}

################################################################

=pod

=item setWeights($nrow, $ncol, @weights)

Specify the weight matrix

=cut
sub setWeights {
    my ($self,$nrow, $ncol, @weights) = @_;
    $self->force_attribute("nrow", $nrow);
    $self->force_attribute("ncol", $ncol);
    @{$self->{weights}} = @weights;
    $self->force_attribute("weight_specified", 1);
}

################################################################

=pod

=item calcWeights()

Calculate weights from the frequency matrix.

=cut
sub calcWeights {
    my ($self) = @_;

    ## Get frequency matrix
    my @frequencies = $self->getFrequencies();

    ## Get alphabet
    my @alphabet = $self->getAlphabet();
    if (scalar(@alphabet) <= 0) {
	&main::FatalError("&RSAT::matrix::calcWeights()\tCannot calculate weigths, because the alphabet has not been specified yet.");
    }

    ## Get or calculate prior residue probabilities
    my %prior = $self->getPrior();

    ## get matrix size
    my $nrow = $self->nrow();
    my $ncol = $self->ncol();

    ## Number of decimals (precision) for the weights
    my $decimals;
    if (defined($self->{decimals})) {
      $decimals = $self->get_attribute("decimals");
    } else {
      $decimals = 1;
    }

    ## Calculate the weights
    my @weights = ();
    for my $c (0..($ncol-1)) {
	for my $r (0..($nrow-1)) {
	    my $letter = $alphabet[$r];
	    my $prior = $prior{$letter};
	    my $freq = $frequencies[$c][$r];
	    if ($freq == 0) {
		$weights[$c][$r] = "-Inf";
	    } elsif ($prior <= 0) {
		$weights[$c][$r] = "NA";
	    } else {
		$weights[$c][$r] = log($freq/$prior)/$info_log_denominator;
#		$weights[$c][$r] = sprintf("%.${decimals}f", log($freq/$prior))/$info_log_denominator;
	    }
#	    &RSAT::message::Debug("weight", "r:".$r, "c:".$c, "l:".$letter, "f:".$freq, "pr:".$prior, "w:".$weights[$c][$r]) if ($main::verbose >= 10);
	}
    }
    $self->setWeights($nrow,$ncol,@weights);
    $self->force_attribute("weight_specified", 1);
}

################################################################

=pod

=item getInformation()

Return the information content matrix.

=cut
sub getInformation {
    my ($self) = @_;
    $self->calcInformation();
    return @{$self->{information}};
}

################################################################

=pod

=item setInformation($nrow, $ncol, @information)

Specify the information content matrix.

=cut
sub setInformation {
    my ($self,$nrow, $ncol, @information) = @_;
    $self->force_attribute("nrow", $nrow);
    $self->force_attribute("ncol", $ncol);
    @{$self->{information}} = @information;
    $self->force_attribute("information_specified", 1);
}


################################################################

=pod

=item calcInformation()

Calculate information content from the weight matrix.

Caching: if already calculated, do not calculate anymore.
attribute "force": force calculaton even if aready calculated.

=cut
sub calcInformation {
    my ($self, $force) = @_;

    ## Caching
    if (($self->get_attribute("information_calculated")) && !($force)) {
	&RSAT::message::Warning("Information already calculated before") if ($main::verbose >= 4);
	return;
    }

    ## Calculate frequencies if required
    unless ($self->get_attribute("frequencies_specified")) {
	$self->calcFrequencies();
    }
    my @frequencies = $self->getFrequencies();
#    my @frequencies = $self->getCrudeFrequencies();


    ## Get or calculate prior residue probabilities
    my %prior = $self->getPrior();
    my $min_prior = &RSAT::stats::min(values %prior);
    $self->set_parameter("min.prior", $min_prior);

    ## Get alphabet
    my @alphabet = $self->get_attribute("alphabet");
    if (scalar(@alphabet) <= 0) {
	&main::FatalError("&RSAT::matrix::calcInformation()\tCannot calculate weigths, because the alphabet has not been specified yet.");
    }
    $self->set_parameter("alphabet.size", scalar(@alphabet));

    ## Maximal number of bits per column
    my $max_bits = log(scalar(@alphabet))/log(2);
    $self->set_parameter("max.bits", $max_bits);

    ## Logarithmic base for the information content
    unless ($self->get_attribute("info.log.base")) {
      $self->set_parameter("info.log.base", $info_log_base);
    }

    ## Matrix size
    my $nrow = $self->nrow();
    my $ncol = $self->ncol();

    ## Calculate information contents
    my @information = (); ## Information matrix
    my @column_information = (); ## Information per column
    my $total_information = 0; ## Total information for the matrix
    for my $c (0..($ncol-1)) {
	for my $r (0..($nrow-1)) {
	    my $letter = $alphabet[$r];
	    my $prior = $prior{$letter};
	    my $freq = $frequencies[$c][$r];
	    if ($freq == 0) {
		$information[$c][$r] = 0;
	    } else {
		$information[$c][$r] = $freq * log($freq/$prior)/$info_log_denominator;
	    }
	    $column_information[$c] += $information[$c][$r];
	    $total_information += $information[$c][$r];
#	    &RSAT::message::Debug("Information", $r, $c, $information[$c][$r], $total_information) if ($main::verbose >= 10);
	}
    }
    $self->setInformation($nrow,$ncol,@information);


    ## Information per column
    $self->push_attribute("column.information", @column_information);

    ## Total information for the matrix
    $self->set_parameter("total.information", $total_information);
    $self->set_parameter("information.per.column", $total_information/$self->ncol());

    ## Maximal information per column
    my $max_possible_info_per_col = -log($min_prior)/$info_log_denominator;
    $self->set_parameter("max.possible.info.per.col", $max_possible_info_per_col);

    ## Remember that info was calculated once
    $self->force_attribute("information_calculated", 1);
}


################################################################

=pod

=item multiply()

Multiply each cell of the counts matrix by a given factor.

Usage: $matrix->multiply($n);

=cut
sub multiply {
  my ($self, $n) = @_;

  ## count matrix
  my @matrix = $self->getMatrix();
  my $ncol = $self->ncol();
  my $nrow = $self->nrow();

  for my $c (0..($ncol-1)) {
    my $col_sum = 0;
    for my $r (0..($nrow-1)) {
      $matrix[$c][$r] *= $n;
    }
  }
  $self->setMatrix($nrow, $ncol, @matrix);
}

################################################################

=pod

=item getFrequencies()

Return the matrix of frequencies. Beware: these frequencies are taking
pseudp-weights into account.

=cut
sub getFrequencies {
    my ($self) = @_;
    unless ($self->get_attribute("frequencies_specified")) {
	$self->calcFrequencies();
    }
    return @{$self->{frequencies}};
}

################################################################

=pod

=item setFrequencies($nrow, $ncol, @frequencies)

Specify the matrix of frequencies. Beware: these frequencies are
taking pseudp-weights into account.

=cut
sub setFrequencies {
    my ($self,$nrow, $ncol, @frequencies) = @_;
    $self->force_attribute("nrow", $nrow);
    $self->force_attribute("ncol", $ncol);
    @{$self->{frequencies}} = @frequencies;
    $self->force_attribute("frequencies_specified", 1);
}

################################################################

=pod

=item getMarkovModel()

Return the RSAT::MarkovModel object associated to the matrix

=cut
sub getMarkovModel {
    my ($self) = @_;
    return $self->{bg_markov_model};
}


################################################################

=pod

=item getCrudeFrequencies()

Return the matrix of crude frequencies, i.e. NOT corrected by
pseudo-counts.

=cut
sub getCrudeFrequencies {
    my ($self) = @_;
    unless ($self->get_attribute("crudeFrequencies_specified")) {
	$self->calcFrequencies();
    }
    return @{$self->{crudeFrequencies}};
}

################################################################

=pod

=item setMarkovModel($bg_model)

Link the matrix to a specified RSAT::MarkovModel object

=cut
sub setMarkovModel {
  my ($self,$bg_model) = @_;
  $self->force_attribute("bg_markov_model", $bg_model);

  unless ($self->get_attribute("bg_order_specified")){
  	$self->set_parameter("bg_markov_order", $bg_model->get_attribute("order"));
  	$self->set_attribute("bg_order_specified", 1);
  }

  ## specify priors from the sufix probabilities of the Markov model
  my %bg_suffix_proba = $bg_model->get_attribute("suffix_proba");
  $self->setPrior(%bg_suffix_proba);

  ## recalculate the frequencies if necessary
  unless ($self->get_attribute("frequencies_specified")) {
	$self->calcFrequencies();
    }
}


################################################################

=pod

=item setCrudeFrequencies($nrow, $ncol, @crudeFrequencies)

Specify the matrix of crude frequencies, i.e; NOT corrected by
pseudo-counts.

=cut
sub setCrudeFrequencies {
  my ($self,$nrow, $ncol, @crudeFrequencies) = @_;
  $self->force_attribute("nrow", $nrow);
  $self->force_attribute("ncol", $ncol);
  @{$self->{crudeFrequencies}} = @crudeFrequencies;
  $self->force_attribute("crudeFrequencies_specified", 1);
}

################################################################

=pod

=item calcFrequencies()

Calculate frequencies from the count matrix (corrected with
pseudo-counts).

=cut
sub calcFrequencies {
    my ($self) = @_;

    ## Get alphabet
    my @alphabet = $self->get_attribute("alphabet");
    if (scalar(@alphabet) <= 0) {
	&main::FatalError("&RSAT::matrix::calcFrequencies()\tCannot calculate weigths, because the alphabet has not been specified yet.");
    }

    ## Matrix size
    my ($nrow, $ncol) = $self->size();
#    my $ncol = $self->ncol();
    if ($ncol <= 0) {
	&main::FatalError("&RSAT::matrix::calcFrequencies()\tCannot calculate frequencies for an empty matrix (not a single column).");
    }
    if ($nrow <= 0) {
	&main::FatalError("&RSAT::matrix::calcFrequencies()\tCannot calculate frequencies for an empty matrix (not a single row).");
    }

    ## Get or calculate prior residue probabilities
    my %prior = $self->getPrior();
    if (scalar(keys %prior) <= 0) {
	&main::Warning( "No prior defined: using equiprobable residues") if ($main::verbose >= 4);
	my $alphabet_size = scalar(@alphabet);
	foreach my $letter (@alphabet) {
	    $prior{$letter} = 1/$alphabet_size;
#	    &RSAT::message::Debug($letter, $prior{$letter}) if ($main::verbose >= 10);
	}
    }

#    &RSAT::message::Debug("&RSAT::matrix::calcFrequencies()", "residue priors", join(" ", %prior))
#      if ($main::verbose >= 10);

    ## pseudo-count
    my $pseudo = $self->get_attribute("pseudo") || 0;

    ## count matrix
    my @matrix = $self->getMatrix();

    ## Calculate the frequencies
    my @frequencies = ();
    my @crude_frequencies = ();
#    my @col_sum = &RSAT::matrix::col_sum(@matrix);
    my $alphabet_size = scalar(keys(%prior));

    for my $c (0..($ncol-1)) {
      my $col_sum = 0;
      for my $r (0..($nrow-1)) {
	my $letter = $alphabet[$r];
	my $prior = $prior{$letter};
	my $occ = $matrix[$c][$r];
	$col_sum += $occ;
	if ($self->get_attribute("equi_pseudo")) {
	  ## Equiprobable repartition of the pseudo-count
	  $frequencies[$c][$r] = $occ + $pseudo/$alphabet_size;
	  #	&RSAT::message::Info("Equiprobable distribution of the pseudo-count") if ($main::verbose >= 10);
	} else {
	  ## Distribute pseudo-count according to prior
	  $frequencies[$c][$r] = $occ + $pseudo*$prior{$letter};
	  #		&RSAT::message::Info("pseudo-count distributed according to prior") if ($main::verbose >= 10);
	}
	#	    &RSAT::message::Debug("freq", $r, $c, $letter, $prior, $pseudo, $occ, $col_sum) unless ($letter);
	#	    &RSAT::message::Debug("freq", $r, $c, $letter, $prior, $pseudo, $occ, $col_sum) if ($main::verbose >= 10);
      }
      for my $r (0..($nrow-1)) {
	if ($col_sum eq 0) {
	  $crude_frequencies[$c][$r] = 0;
	} else {
	  $crude_frequencies[$c][$r] = $matrix[$c][$r]/$col_sum;
	}
	if (($col_sum + $pseudo) > 0) {
	  $frequencies[$c][$r] /= ($col_sum + $pseudo);
	} else {
	  $frequencies[$c][$r] = 0;
	}
	#	  &RSAT::message::Debug("freq", $r, $c, $pseudo,
	#				$col_sum,
	#				"a:".$matrix[$c][$r],
	#				"f:".$crude_frequencies[$c][$r],
	#				"f':".$frequencies[$c][$r])
	#	    if ($main::verbose >= 10);
      }
    }
    $self->setFrequencies($nrow,$ncol,@frequencies);
    $self->setCrudeFrequencies($nrow,$ncol,@crude_frequencies);
}

################################################################

=pod

=item calcProbabilities()

Calculate probabilities (with the binomial distribution) from the
count matrix.

=cut
sub calcProbabilities {
    my ($self) = @_;

    die "The procedure calcProbabilities() is in construction";

    ## Get alphabet
    my @alphabet = $self->get_attribute("alphabet");
    if (scalar(@alphabet) <= 0) {
	&main::FatalError("&RSAT::matrix::calcProbabilities()\tCannot calculate weigths, because the alphabet has not been specified yet.");
    }

    ## Matrix size
    my ($nrow, $ncol) = $self->size();
    if (($nrow <= 0) ||
	($ncol <= 0)) {
	&main::FatalError("&RSAT::matrix::calcProbabilities()\tCannot calculate probabilities for an empty matrix.");
    }


    ## Get or calculate prior residue probabilities
    my %prior = $self->getPrior();
    if (scalar(keys %prior) <= 0) {
	&main::Warning( "No prior defined: using equiprobable residues") if ($main::verbose >= 4);
	my $alphabet_size = scalar(@alphabet);
	foreach my $letter (@alphabet) {
	    $prior{$letter} = 1/$alphabet_size;
#	    warn join "\t", "|", $letter, $prior{$letter}, "\n" if ($main::verbose >= 10);
	}
    }

    ## pseudo-count
    my $pseudo = $self->get_attribute("pseudo");

    ## count matrix
    my @matrix = $self->getMatrix();

    ## Calculate the frequencies
    my @frequencies = ();
    my @crude_frequencies = ();
#    my @col_sum = &RSAT::matrix::col_sum(@matrix);

    for my $c (0..($ncol-1)) {
	my $col_sum = 0;
	for my $r (0..($nrow-1)) {
	    my $letter = $alphabet[$r];
	    my $prior = $prior{$letter};
	    my $occ = $matrix[$c][$r];
	    $col_sum += $occ;
	    $frequencies[$c][$r] = $occ + $pseudo*$prior{$letter};
#	    warn join "\t", "freq", $r, $c, $letter, $prior, $pseudo, $occ, $col_sum, "\n" if ($main::verbose >= 10);
	}
	for my $r (0..($nrow-1)) {
	    if ($col_sum eq 0) {
		$crude_frequencies[$c][$r] = 0;
	    } else {
		$crude_frequencies[$c][$r] = $matrix[$c][$r]/$col_sum;
	    }
	    $frequencies[$c][$r] /= ($col_sum + $pseudo);
	    warn join( "\t", "freq", $r, $c, $pseudo,
		       $col_sum,
		       "a:".$matrix[$c][$r],
		       "f:".$crude_frequencies[$c][$r],
		       "f':".$frequencies[$c][$r]), "\n"
			   if ($main::verbose >= 10);
	}
    }

    $self->setFrequencies($nrow,$ncol,@frequencies);
    $self->setCrudeFrequencies($nrow,$ncol,@crude_frequencies);
}


################################################################

=pod

=item &calcConsensus($force)

Calculate the consensus.

Caching: if already calculated, do not calculate anymore.

Attribute "force": force calculaton even if aready calculated.

=cut
sub calcConsensus {
    my ($self, $force) = @_;

    ## Caching
    if (($self->get_attribute("consensus_calculated")) && !($force)) {
	warn "Consensus already calculated before\n" if ($main::verbose >= 4);
	return;
    }

    ## Calculate weight only if required
    unless ($self->get_attribute("weight_specified")) {
	$self->calcWeights();
    }
    my @weights = $self->getWeights();

    my @alphabet = $self->getAlphabet();

    ## Calculate consensus
    my $nrow = $self->nrow();
    my $ncol = $self->ncol();
    my $consensus = "";
    my $consensus_strict = "";
    for my $c (0..($ncol-1)) {
	my $col_max = 0;
	my $col_consensus = "-";
	my %positive_score = ();
	for my $r (0..($nrow - 1)) {
	    my $weight = $weights[$c][$r];
	    if ((&main::IsReal($weight)) && ($weight >= 0)) {
		my $letter = $alphabet[$r];
		$positive_score{$letter} = $weight;
		if ($weight > $col_max) {
		    $col_max = $weight;
#		die join "\t", $c, $r, $col_max, $alphabet[$r], $col_consensus;
		    $col_consensus = $letter;
		}
	    }
	}

	## Calculate degenerate code
	my  $regular = $col_consensus;
	if (scalar(keys %positive_score) >= 2) {
	    $regular = "[";
	    $regular .= join "", sort keys %positive_score;
	    $regular .= "]";
	}

	## Use uppercase for scores >= 1
	if ($col_max >= 1) {
	    $consensus_strict .= uc($col_consensus);
	    $consensus .= uc($regular);
	} else {
	    $consensus_strict .= lc($col_consensus);
	    $consensus .= lc($regular);
	}
    }
    my $consensus_IUPAC = &main::regular_to_IUPAC($consensus);

    ## Strict consensus
    $self->set_parameter("consensus.strict", $consensus_strict);
    $self->set_parameter("consensus.strict.rc", &RSAT::SeqUtil::ReverseComplement($consensus_strict));

    ## Degenerate consensus in IUPAC format
    $self->set_parameter("consensus.IUPAC", $consensus_IUPAC);
    $self->set_parameter("consensus.IUPAC.rc", &RSAT::SeqUtil::ReverseComplement($consensus_IUPAC));

    ## Degenerate consensus in regexp format
    $self->set_parameter("consensus.regexp", $consensus);
    $self->set_parameter("consensus.regexp.rc", &RSAT::SeqUtil::ReverseComplement($consensus));

    ## Remember that the consensus has been calculated
    $self->force_attribute("consensus_calculated", 1);

}

################################################################

=pod

=item &calcConsensus($force)

Calculate the GC content of a matrix.


=cut
sub calcGCcontent {
	my ($self) = @_;

	&RSAT::message::Info(join("\t", "Calculating GC content"))
	if ($main::verbose >= 5);

    my @matrix_types = ("crude.freq","corrected.freq");

    foreach my $matrix_type (@matrix_types){
    	my @matrix = ();

    	if ($matrix_type eq "crude.freq"){
    		@matrix = $self->getCrudeFrequencies();
    	} elsif ($matrix_type eq "corrected.freq"){
    		@matrix = $self->getFrequencies();
    	} else {
    		&RSAT::message::Warning("No Frequency matrix found. GC content calculation skipped.");
    		last;
    	}

    	my @alphabet = $self->getAlphabet();
      	my $ncol = $self->ncol();
      	my $nrow = $self->nrow();

      	## calculate the sum of each row
	  	my %row_sums =();
      	foreach my $r (0..($nrow-1)) {
			my @row = &RSAT::matrix::get_row($r, $ncol, @matrix);
			my $row_sum = 0;
			for my $c (0..($ncol-1)) {
				$row_sum += $matrix[$c][$r];
			}
			my $letter = $alphabet[$r];
			$row_sums{$letter} = ($row_sum/$ncol);
      	}

      	my $residues_content ="";
      	foreach my $residue (sort(keys(%row_sums))){
      		$residues_content .= $residue.":".sprintf("%.4f",$row_sums{$residue})."|";
      	}
      	chop($residues_content);
     
     	 ## Store as parameter
    	$self->set_parameter("residues.content.".$matrix_type, $residues_content);
    	$self->set_parameter("G+C.content.".$matrix_type, ($row_sums{g}+$row_sums{c}));
    }
}

################################################################

=pod

=item _printProfile()

Print the matrix in profile format (one column per residue, one row
per position), with additional columns for the consensus, some
statistics and the profile (graphical representations)

=cut

sub _printProfile {
    my ($self, $to_print) = @_;
    @matrix = @{$self->{table}};
    my @alphabet = $self->getAlphabet();
    my $ncol = $self->ncol();
    my $nrow = $self->nrow();
    my $max_profile = $self->get_attribute("max_profile");
    unless ($max_profile) {
      if (scalar(@aqlphabet) == 4) {
	$max_profile = 24;
      } else {
	$max_profile = 20;
      }
    }
    my $comment_char = "|";


    ## Temporarily suppress the pipe
    my $pipe_bk = $self->get_attribute("pipe");

    $self->force_attribute("pipe", "");

    $to_print .= "; Profile matrix\n";

    ## Get the consensus
    $self->calcConsensus();
    my @consensus_strict = split "|", $self->get_attribute("consensus.strict");
    my @consensus_IUPAC = split "|", $self->get_attribute("consensus.IUPAC");

    ## Get the information per column
    my @information = $self->getInformation();
    my @weights = $self->getWeights();
    my @info_sum = &RSAT::matrix::col_sum($nrow, $ncol, @information);

    ## Maximal information content per column, for scaling the pseudo-logo profile
    my $max_bits = $self->get_attribute("max.bits");
    my $max_possible_info_per_col = $self->get_attribute("max.possible.info.per.col");

    ## profile header
    my $profile_scale = "";
    for my $i (1..$max_profile) {
      my $scale_value = $i*$max_bits/$max_profile;
      if ($scale_value == sprintf("%d", $scale_value) ) {
	$profile_scale .= $scale_value;
      } else {
	$profile_scale .= "-";
      }
    }
    $to_print .= $self->_printMatrixRow(";pos",
					@alphabet,
					$comment_char,
					"sum",
					"max_frq",
#					"max",
#					"min",
					"inf_sum",
					"strict",
					"IUPAC",
					$profile_scale,
				       );

#    $to_print .= $self->_printSeparator(scalar(@alphabet));

    ## print each matrix column as a row in the output
    my $matrix_max = &main::checked_max(&RSAT::matrix::col_max($nrow, $ncol, @matrix));
    my $scale = $max_profile/$matrix_max;

    for my $c (0..($ncol-1)) {
	my @row = &RSAT::matrix::get_column($c+1, $nrow, @matrix);
	my @row_weights = &RSAT::matrix::get_column($c+1, $nrow, @weights);
	my $sum = &main::sum(@row);
	my $max = &main::checked_max(@row);
	my $min = &main::checked_min(@row);
	my $profile_length = &main::round($max*$scale);

	## Logo-type profile
	my $column_info = $info_sum[$c];
	my $column_info_bits = $column_info / $max_possible_info_per_col;
	my $consensus_profile = "";
	my $cum_len = 0;
	my $prev_cum_len = 0;
	for my $i (0..$#row) {
	  my $residue = $alphabet[$i];
	  if (($max_possible_info_per_col > 0) && ($sum > 0)) {
	    $cum_len += $profile_length * ($row[$i]/$sum) * ($column_info/$max_possible_info_per_col);
	  }
	  for my $j (($prev_cum_len+1)..sprintf("%d",$cum_len)) {
	    if ($row_weights[$i] >= 1) {
	      $consensus_profile .= uc($alphabet[$i]);
	    } else {
	      $consensus_profile .= lc($alphabet[$i]);
	    }
	  }
	  $prev_cum_len = sprintf("%d",$cum_len);
	}


	if ($sum <= 0) {
	    $rel_max = "NA";
	} else {
	    $rel_max = sprintf("%5.2f", $max/$sum);
	}
	$to_print .= $self->_printMatrixRow($c+1,
					    @row,
					    $comment_char,
					    $sum,
					    $rel_max,
#					    $max,
#					    $min,
					    sprintf("%5.2f",$info_sum[$c]),
					    $consensus_strict[$c],
					    $consensus_IUPAC[$c],
					    $consensus_profile,
					   );

    }
    $self->force_attribute("pipe", $pipe_bk);
    return ($to_print);
}

################################################################

=pod

=item _printParameters()

Return a string with the parameter values

=cut

sub _printParameters {
  my ($self, $to_print) = @_;
  $to_print .= ";\n";
  $to_print .= "; Matrix parameters\n";

  ## Matrix size
  $to_print .= sprintf ";\t%-29s\t%g\n", "Columns", $self->ncol();
  $to_print .= sprintf ";\t%-29s\t%g\n", "Rows", $self->nrow();

  ## Alphabet
  $to_print .= sprintf ";\t%-29s\t%s\n", "Alphabet", join("|", $self->getAlphabet());

  ## Prior probabilities
  my @prior_tmp = ();
  my %prior = $self->getPrior();
  foreach my $letter (sort keys %prior) {
    push @prior_tmp, $letter.":".$prior{$letter};
  }
  $to_print .= sprintf ";\t%-29s\t%s\n", "Prior", join("|", @prior_tmp);

  ## Matrix attributes
  my ($proba_min, $proba_max) = $self->proba_range();
  my ($Wmin, $Wmax) = $self->weight_range();

  my @params = $self->get_attribute("parameters");
  my %printed = ();
  for my $param (@params) {
    ## Print only once if the param was entered several times
    next if $printed{$param};
    $printed{$param}++;

    if ($self->get_attribute($param)) {
      if (&main::IsInteger($self->get_attribute($param))) {
	$to_print .= sprintf ";\t%-29s\t%d\n", $param, $self->get_attribute($param);
      } elsif (&main::IsReal($self->get_attribute($param))) {
	$to_print .= sprintf ";\t%-29s\t%g\n", $param, $self->get_attribute($param);
      } else {
	$to_print .= sprintf ";\t%-29s\t%s\n", $param, $self->get_attribute($param);
      }
    }
  }
  return ($to_print);
}


################################################################

=pod

=item _printMatrixRow($row_name, @values)

Print a row for the matrix output.

=cut

sub _printMatrixRow {
    my ($self, $row_name, @values) = @_;
    my $row_string = $row_name;
    my $ncol = scalar(@values);

    ## Format for the matrix entries
    my $col_width = $self->get_attribute("col_width");
    my $number_width = 0;
    if ($col_width) {
  	$number_width = $col_width - 1;
    } else {
	$number_width = 5;
    }

    ## Number of decimals for floating numbers
    my $decimals;
    if (defined($self->{decimals})) {
      $decimals = $self->get_attribute("decimals");
    } else {
      if ($type eq "counts") {
	$decimals = 0;
      } else {
	$decimals = $number_width - 3;
      }
    }

    ## Separator between columns
    my $sep = $self->get_attribute("sep") || "\t";
#    my $sep="boum";

#    &RSAT::message::Debug("w=".$col_width, "sep='".$sep."'", "pos=".$pos, "decimals=".$decimals, "number_width=".$number_width) if ($main::verbose >= 10);

    ## Print the matrix row
    my $pipe = $self->get_attribute("pipe");
    $row_string .= $sep.$pipe if ($pipe);
    for $c (0..($ncol-1)) {
	my $value;
	if (defined($values[$c])) {
	  $value = $values[$c];
	} else {
	  $value = "UNDEF";
	}
	if ($col_width) {
	    my $value_format = "%${number_width}s";
	    if (&main::IsReal($value)){
		if ($type eq "counts") {
		    $value_format = "%${number_width}d";
		} else {
		    $value_format= "%${number_width}.${decimals}f";
		}
	    }
	    $row_string .= sprintf " ${value_format}", $value;
	} else {
	    $row_string .= $sep.$value;
	}
    }
    $row_string .= "\n";
    return $row_string;
}

################################################################

=pod

=item get_row($row_nb, $ncol, @table)

Return a row of the table as a list.

=cut
sub get_row {
    my ($row_nb, $ncol, @table) = @_;
    my @row = ();
    for my $c (0..($ncol-1)) {
	push @row, $table[$c][$row_nb-1];
    }
    return @row;
}

################################################################

=pod

=item get_column($col_nb, $nrow, @table)

Return a column of the table as a list.

=cut
sub get_column {
    my ($col_nb, $nrow, @table) = @_;
    my @col = ();

    for my $r (0..($nrow-1)) {
	push @col, $table[$col_nb-1][$r];
    }
    return @col;
}


=pod

=item add_column

Add a column either on the left or the right side of the matrix.

Usage: $matrix->add_column($side, @col_values)

=cut

sub add_column {
  my ($self, $side, @col_values) = @_;
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
#  &RSAT::message::Debug("&RSAT::matrix::add_column()", $side, join(",", @col_values)) if ($main::verbose >= 5);
  if (scalar(@col_values) != $nrow) {
    &RSAT::message::FatalError("&RSAT::matrix:::add_column()",
			       "invalid number of values",
			       scalar(@col_values));
  }

  ## Add a column on the right side
  if ($side eq "right") {
    my $new_col = $ncol + 1;
    @{$self->{table}}[$new_col-1] = \@col_values;
  } elsif ($side eq "left") {
    my $new_col = $ncol + 1;
    ## Shift all columns one position rightward
    for my $i (1..$ncol) {
      for my $r (1..$nrow) {
	$self->{table}[$ncol - $i +1][$r-1] = $self->{table}[$ncol - $i][$r-1];
      }
    }
    @{$self->{table}}[0] = \@col_values;
  } else {
    &RSAT::error::FatalError("&RSAT::matrix:::add_column()",
			     $side, "invalid side (supported: right|left)");
  }

  $self->force_attribute("ncol", $ncol+1);

}

################################################################

=pod

=item permute_columns()

Permute the columns of the matrix

=cut
sub permute_columns {

  my ($self) = @_;

  my @matrix = @{$self->{table}};
  my @perm_matrix = ();

  ## Permute entire columns
  #my $perm_col_values;
  my @perm_col_values = ();;
  my $ncol = $self->ncol();
  my $nrow = $self->nrow();
  my @cols = 0..($ncol-1);
  my @perm_col = &RSAT::stats::permute(@cols);
  &RSAT::message::Debug("RSAT::matrix::permute_columns", "permutation", join(",", @perm_col)) if ($main::verbose >= 5);

  foreach my $c (@cols) {
    my @perm_values =  &RSAT::matrix::get_column($perm_col[$c], $nrow, @matrix);
    push @{$perm_col_values[$c]}, @perm_values;
  }

  for my $r (0..($nrow-1)) {
    for my $c (0..($ncol-1)) {
      $perm_matrix[$c][$r] = $perm_col_values[$c][$r];
    }
  }
#  @{$self->{perm_columns}} = @perm_matrix;
  @{$self->{table}} = @perm_matrix;
  foreach my $attr qw(frequencies_specified
		      crudeFrequencies_specified
		      weight_specified
		      information_specified
		      consensus_specified
		     ) {
    $self->force_attribute($attr, 0);
  }
}



################################################################

=pod

=item col_sum($nrow, $ncol, @table)

Calculate the sum of each column of a table (is applied to the
different types of table used in this class).

Return a vector of the same length as the table width.

=cut
sub col_sum {
    my ($nrow, $ncol, @table) = @_;
#    die join "\t", $nrow, $ncol, join( " ", @{$matrix[0]});

    warn join("\t", "; Calculating sum per column for a table",$nrow, $ncol),"\n"
	if ($main::verbose > 3);

    my @col_sum = ();
    for my $c (0..($ncol-1)) {
	my $col_sum = 0;
	for my $r (0..($nrow-1)) {
	    $col_sum += $table[$c][$r];
	}
	push @col_sum, $col_sum;
    }
    return(@col_sum);
}


################################################################

=pod

=item col_max($nrow, $ncol, @table)

Calculate the max of each column of a table (is applied to the
different types of table used in this class).

Return a vector of the same length as the table width.

=cut
sub col_max {
    my ($nrow, $ncol, @table) = @_;

    warn join("\t", "; Calculating max per column",$nrow, $ncol),"\n"
	if ($main::verbose > 3);

    my @col_max = ();
    for my $c (0..($ncol-1)) {
	my @col_values = ();
	for my $r (0..($nrow-1)) {
	    push @col_values, $table[$c][$r];
	}
	my $col_max = &main::checked_max(@col_values);
	push @col_max, $col_max;
    }
    return(@col_max);
}

################################################################

=pod

=item col_min($nrow, $ncol, @table)

Calculate the min of each column of a table (is applied to the
different types of table used in this class).

Return a vector of the same length as the table width.

=cut
sub col_min {
    my ($nrow, $ncol, @table) = @_;

    warn join("\t", "; Calculating min per column",$nrow, $ncol),"\n"
	if ($main::verbose > 3);

    my @col_min = ();
    for my $c (0..($ncol-1)) {
	my @col_values = ();
	for my $r (0..($nrow-1)) {
	    push @col_values, $table[$c][$r];
	}
	my $col_min = &main::checked_min(@col_values);
	push @col_min, $col_min;
    }
    return(@col_min);
}

################################################################

=pod

=item B<seq_proba($sequence)>

Calculate the probability of each segment of an input sequence.

The probability of a segment of sequence of lenghth w is the product of the
corrected frequencies.

If the input sequence has length L > w, the return value is a vector of L-w+1
probability values.

=cut

sub seq_proba {
    my ($self, $sequence) = @_;
    my @proba = ();

    my $L = length($sequence);
    my ($nrow, $ncol) = $self->size();

    &RSAT::message::TimeWarn(join("\t", "seq_proba", "sequence length:".$L)) if ($main::verbose >= 5);

    if ($L < $ncol) {
	&RSAT::message::Warning("Sequence length ($L) is shorter than the matrix width ($ncol). Skipped.");
    }

    ## Iterate over sequence segments
    for my $i (0..$L-$ncol) {
	my $segment = substr($sequence, $i, $ncol);
#	my $segment_proba = 1;
#	for my $c (0..($ncol-1)) {
#	my $letter = shift @letters;
#	    my $letter = substr($segment, $c, 1);
#	    my $r = $self->{"alphabet_index"}->{$letter};
#	    my $letter_proba = $self->{"frequencies"}[$c][$r];
#	    $segment_proba *= $letter_proba;
#	}
	my $segment_proba = $self->segment_proba($segment);
	push @proba, $segment_proba;
#	&RSAT::message::Debug("segment proba", $i, $segment, $segment_proba) if ($main::verbose >= 10);
    }

    return @proba;
}



################################################################

=pod

=item B<segment_proba($segment)>

Calculate the probability of a segment of sequence. The length of the sequence
segment must equal the matrix width.

The probability of a segment of sequence of lenghth w is the product of the
corrected frequencies.

=cut

sub segment_proba {
    my ($self, $segment) = @_;
    $segment = lc($segment);
    my $seq_len = length($segment);
    my @residue_proba = ();

    my $order = $self->get_attribute("bg_markov_order");
    $segment =  lc($segment);
    my $segment_proba = 1;


    &RSAT::message::Debug("Segment:", $segment, "Markov:".$order)
	if ($main::verbose >= 5);

    ## for Bernouiili model
    if ($order == 0) {
	for my $c (0..($seq_len-1)) {
	    my $letter = substr($segment, $c, 1);
	    if (defined($self->{"alphabet_index"}->{$letter})) {
		$r = $self->{"alphabet_index"}->{$letter};
		$letter_proba = $self->{"frequencies"}[$c][$r];
		push @residue_proba, $letter_proba;
	    } else {
		if ((lc($letter) eq "n") &&
		    ($self->get_attribute("n_treatment") eq "score")) {
		    $letter_proba = 1;
		    push @residue_proba, $letter_proba;
		}
	    }
	    $segment_proba *= $letter_proba;
	}
	### for higher Mrkov order
    } else {
	##prefix treatment
	my $prefix = substr($segment,0,$order);
	my @prefix_residues = split //,$prefix;
	my $prefix_proba = 1;

	## calculation of the prefix probability
	for my $c (0..$#prefix_residues) {
	    my $letter =  $prefix_residues[$c];
	    if (defined($self->{"alphabet_index"}->{$letter})) {
		$r = $self->{"alphabet_index"}->{$letter};
		$prefix_proba *=  $self->{"frequencies"}[$c][$r];
	    } else {
		if ((lc($pr) eq "n") &&
		    ($self->get_attribute("n_treatment") eq "score")) {
		    $prefix_proba *= 1;
		}
	    }
	}
	$segment_proba *= $prefix_proba;
	push @residue_proba, $prefix_proba;

	### for the remaining residue of $segment
	for $c ($order..($seq_len-1)) {
	    my $letter_proba = 0;
	    $letter = substr($segment, $c, 1);
	    if (defined($self->{"alphabet_index"}->{$letter})) {
		$r = $self->{"alphabet_index"}->{$letter};
		$letter_proba = $self->{"frequencies"}[$c][$r];
		push @residue_proba, $letter_proba;
	    } else {
		if ((lc($letter) eq "n") &&
		    ($self->get_attribute("n_treatment") eq "score")) {
		    $letter_proba = 1;
		    push @residue_proba, $letter_proba;
		}
	    }
	    $segment_proba *= $letter_proba;
	}

    }

    for my $col (0..$#residue_proba){
	&RSAT::message::Debug("Proba_residue_M",$col,sprintf("%.6f",$residue_proba[$col]))
	    if ($main::verbose >= 5);
    }
    return \@residue_proba,$segment_proba;
}


################################################################

=pod

=item B<segment_weight_Bernoulli($segment)>

Calculate the weight of a segment of sequence. The length of the sequence
segment must equal the matrix width.

The weight of a segment of sequence of lenghth w is computed as the
sum of the weights of its residues at the corresponding positions of
the matrix. This method is thus only valid for Bernoulli models.

=cut

sub segment_weight_Bernoulli {
    my ($self, $segment) = @_;
    $segment = lc($segment);

    my $segment_weight = 0;
    my $seq_len = length($segment);
    my $r;
    for my $c (0..($seq_len-1)) {
	my $letter = substr($segment, $c, 1);
	my  $letter_weight = 0;
	if (defined($self->{"alphabet_index"}->{$letter})) {
	    $r = $self->{"alphabet_index"}->{$letter};
	    $letter_weight = $self->{"weights"}[$c][$r];
	} else {
	  if ((lc($letter) eq "n") &&
	      ($self->get_attribute("n_treatment") eq "score")) {
	    $letter_weight = 0;
	  }
	}
	$segment_weight += $letter_weight;
#	&RSAT::message::Debug("segment_proba", "letter:".$letter, "col:".$c, "row:".$r, "P(letter)=".$letter_proba, "P(segm)=".$segment_proba) if ($main::verbose >= 10);
    }

#    &RSAT::message::Debug("segment_proba", $segment, "P(segm)=".$segment_proba) if ($main::verbose >= 10);
    return $segment_weight;
}

################################################################

=pod

=item B<proba_range()>

Return the range (min and max possible values) for a sequence segment
probability.

The min (max) value is the product of the minimal (maximal) per column
from the matrix of corrrected frequencies.

Usage: my ($proba_min, proba_max)  = $matrix->proba_range();

=cut

sub proba_range {
    my ($self) = @_;
    my $proba_min = 1;
    my $proba_max = 1;

    ## Calculate frequencies if required
    unless ($self->get_attribute("frequencies_specified")) {
	$self->calcFrequencies();
    }

    my ($nrow, $ncol) = $self->size();
    my @frequencies = $self->getFrequencies();

    foreach my $c (0..($ncol-1)) {
	my $col_min = 1;
	my $col_max = 0;
	foreach my $r (0..($nrow-1)) {
	    my $freq = $frequencies[$c][$r];
	    $col_min = &RSAT::stats::min($col_min, $freq);
	    $col_max = &RSAT::stats::max($col_max, $freq);
	}
	$proba_min *= $col_min;
	$proba_max *= $col_max;
    }

    $self->set_parameter("min(P(S|M))", $proba_min);
    $self->set_parameter("max(P(S|M))", $proba_max);
    $self->set_parameter("proba_range", $proba_max-$proba_min);
    &RSAT::message::Info(join("\t", "min(P(S|M))", $proba_min)) if ($main::verbose >= 4);
    &RSAT::message::Info(join("\t", "max(P(S|M))", $proba_max)) if ($main::verbose >= 4);
    return ($proba_min, $proba_max);
}


################################################################

=pod

=item B<weight_range()>

Return the range (min and max possible values) for a sequence segment
weight. Attention, these values are only correct for Bernoulli models.

The min (max) value is the sum of the minimal (maximal) per column
from the matrix of weights.

Usage: my ($Wmin, $Wmax, $Wrange)  = $matrix->weight_range();

=cut
sub weight_range {
  my ($self) = @_;
  my $Wmin = 0;
  my $Wmax = 0;


  my @weights = $self->getWeights();

  #    my %score_proba = $self->getTheorScoreDistrib("weights");
  #    my @weights = sort {$a <=> $b} (keys (%score_proba));
  #   $Wmin = $weights[0];
  #   $Wmax = $weights[$#weights];

  ## Calculate min and max weights
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  for my $c (0..($ncol-1)) {
    my @col_weights = 0;
    for my $r (0..($nrow-1)) {
      push @col_weights, $weights[$c][$r];
    }
    $Wmin += &RSAT::stats::min(@col_weights);
    $Wmax += &RSAT::stats::max(@col_weights);
  }

  ## Get the rounded Wmin and Wmax values
  my $decimals = $self->get_attribute("decimals");
  my $factor = 10**$decimals;
  $Wmin = &POSIX::floor($Wmin*$factor)/$factor;
  $Wmax = &POSIX::ceil($Wmax*$factor)/$factor;
  my $Wrange = $Wmax-$Wmin;

  &RSAT::message::Debug("Weights",$c, "min:".$Wmin, "max:".$Wmax, "range:", $Wrange) if ($main::verbose >= 5);

  $self->set_parameter("Wmin", $Wmin);
  $self->set_parameter("Wmax", $Wmax);
  $self->set_parameter("Wrange", $Wrange);
  if ($main::verbose >= 4) {
    &RSAT::message::Info(join("\t", "Wmin", $self->get_attribute("Wmin"))) ;
    &RSAT::message::Info(join("\t", "Wmax", $self->get_attribute("Wmax"))) ;
    &RSAT::message::Info(join("\t", "Wrange", $self->get_attribute("Wrange"))) ;
  }
  return ($Wmin, $Wmax, $Wrange);
}

# sub weight_range {
#     my ($self) = @_;
#     my $tmp_Wmin = 0;
#     my $tmp_Wmax = 0;
#     my ($nrow, $ncol) = $self->size();
#     my @weights = $self->getWeights();

#     foreach my $c (0..($ncol-1)) {
# 	my $col_min="NA";
# 	my $col_max="NA";
# 	foreach my $r (0..($nrow-1)) {
# 	    my $weight = "NA";
# 	    if (defined($weights[$c][$r])) {
# 		$weight = $weights[$c][$r];
# 		if ($col_min eq "NA") {
# 		    $col_min = $weight;
# 		} else {
# 		    $col_min = &RSAT::stats::min($col_min, $weight);
# 		}
# 		if ($col_max eq "NA") {
# 		    $col_max = $weight;
# 		} else {
# 		    $col_max = &RSAT::stats::max($col_max, $weight);
# 		}
# 	    }
# 	    &RSAT::message::Debug("weight_range", "weight", $c, $r, $weight) if ($main::verbose >= 5);
# 	}
# 	$tmp_Wmin += $col_min;
# 	$tmp_Wmax += $col_max;
# 	&RSAT::message::Debug("Weights", "column:".$c, "min:".$tmp_Wmin, "max:".$tmp_Wmax, "range:", $tmp_Wmax - $tmp_Wmin) if ($main::verbose >= 5);
#     }

#     my $tmp_Wrange = $tmp_Wmax-$tmp_Wmin;
#     $self->set_parameter("Wmin", $tmp_Wmin);
#     $self->set_parameter("Wmax", $tmp_Wmax);
#     $self->set_parameter("Wrange", $tmp_Wrange);
#     if ($main::verbose >= 4) {
# 	&RSAT::message::Info(join("\t", "Wmin", $self->get_attribute("Wmin"))) ;
# 	&RSAT::message::Info(join("\t", "Wmax", $self->get_attribute("Wmax"))) ;
# 	&RSAT::message::Info(join("\t", "Wrange", $self->get_attribute("Wrange"))) ;
#     }

#     return ($tmp_Wmin, $tmp_Wmax, $tmp_Wrange);
# }


################################################################

=pod

=item B<treat_null_values>

Replace undefined values by 0 in the count matrix.

=cut
sub treat_null_values {
  my ($self) = @_;
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @matrix = $self->getMatrix();


  for my $c (0..($ncol-1)) {
#    &RSAT::message::Debug ("BEFORE", "col", $c, join("; ", @{$matrix[$c]})) if ($main::verbose >= 10);
    for my $r (0..($nrow-1)) {
      unless (defined($matrix[$c][$r])) {
#	&RSAT::message::Debug("column", $c, "row", $r, "replacing undefined value by 0") if ($main::verbose >= 10);
	$matrix[$c][$r] = 0;
      }
    }
#    &RSAT::message::Debug ("AFTER", "col", $c, join("; ", @{$matrix[$c]})) if ($main::verbose >= 10);
  }
  $self->setMatrix($nrow, $ncol, @matrix);
}


################################################################

=pod

=item B<add_site>

Add a site (sequence) to the matrix and update the count matrix
accordingly.

=cut
sub add_site() {
  my ($self, $site_seq, %args) = @_;
  my $site_id = $args{id} || $site_seq;
  my $score =  $args{score} || 1;
  if ($score <  0) {
    &RSAT::message::Warning("RSAT::matrix::add_site()",
			    "site",
			    $site_seq,
			    "negative score", $score,
			    "set to 0"
			   ) if ($main::verbose >= 5);
    $score = 0;
  }

  my @letters = split "|", $site_seq;

  $self->push_attribute("sequences", $site_seq);
  if ($site_id) {
    $self->push_attribute("site_ids", $site_id);
  }

  my @alphabet = $self->getAlphabet();
  ## Index the alphabet
  my %alphabet = ();
  foreach my $l (0..$#alphabet) {
    $alphabet{$alphabet[$l]} = $l;
  }

  &RSAT::message::Debug("RSAT::matrix", $self->get_attribute("name"),
			"Adding site", $site_seq, $site_id, "len=".scalar(@letters),
			"alphabet", join(":", @alphabet)),
    if ($main::verbose >= 4);

  ## Update the count matrix with the new sequence
  foreach my $c (0..$#letters) {
    if (defined($alphabet{$letters[$c]})) {
      my $row = $alphabet{$letters[$c]};
      if (($args{max_score}) &&
	  (defined(${$self->{table}}[$c][$row]))) {
	  ${$self->{table}}[$c][$row] = &RSAT::stats::max($score, ${$self->{table}}[$c][$row]);
      } else {
	${$self->{table}}[$c][$row] += $score;
      }
    } else {
      &RSAT::message::Warning("&RSAT::matrix::add_site()", $site_seq, "Unrecognized character at position", $c, $letters[$c])
	if ($main::verbose >= 5);
    }
  }

  ## update the number of columns
  my $ncol = &RSAT::stats::max($self->ncol(), scalar(@letters));
  $self->force_attribute("ncol",  $ncol);
}

################################################################

=pod

=item B<calcTheorScoreDistrib>

Calculate the theoretial score distribution for Markov background model
of any order. The score distribution is computed for the weight
(log-likelihood).

For Bernoulli (Markov order 0), the computation is
performed using the algorithm described by Bailey (Bioinformatics,
1999).

For Markov models of higher orders, we extended the algorithm of Bailey and
the calculation of the theorical distribution is coherent with matrix-scan
scoring system.

Usage:

=over

=item T<$self->calcTheorScoreDistrib();>

Calculate proba distribution of weight scores.

Calculate proba distribution of weights, with a precision of user-defined
number of decimals. WARNING: for example, it can take up to 10x more time to compute
distributions with 3 decimals than with 2 decimals.

=cut
sub calcTheorScoreDistrib {
  my ($self, $score_type) = @_;

  ## Bg model defined as Markov model
  if ($self->get_attribute('bg_markov_order') > 0) {
    return $self->calcTheorScoreDistribMarkov();
  } else {
    return $self->calcTheorScoreDistribBernoulli();
  }
}

################################################################

=pod

=item B<calcTheorScoreDistribBernoulli>

Calculates the theorical distribution of weights probabilities based on
a Bernoulli background model.

=cut
sub calcTheorScoreDistribBernoulli {
  my ($self, $score_type) = @_;
  $score_type = $score_type || "weights";

  ################################################################
  ## This parameter drastically affects the speed of computation By
  ## reducing the score to 2 decimals, the nmber of possible scors is
  ## reduced to ~5000 for a typical weight matrix
  ## This prevents the comptation time to increase exponentially with
  ## the matrix width.
  my $decimals = $self->get_attribute("decimals");
  my $score_format = "%.${decimals}f";
  my $score_format_calc = "%.".(${decimals}+3)."f";

  my @scores = $self->getFrequencies();

 # my @scores;
 # if (lc($score_type) eq "counts") {
 #   @scores = $self->getMatrix();
 # } elsif (lc($score_type) eq "weights") {
 #   @scores = $self->getWeights();
 # } elsif (lc($score_type) eq "crudefrequencies") {
  #  @scores = $self->getCrudeFrequencies();
 # } elsif (lc($score_type) eq "frequencies") {
 #   @scores = $self->getFrequencies();
 # }

  &RSAT::message::TimeWarn("Calculating theoretical distribution of ".$score_type,
			   "Bernoulli model",
			   "matrix", $self->get_attribute("name"),
			   "Precision: ".$decimals." decimals",
			  ) if ($main::verbose >= 4);

  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @alphabet = $self->getAlphabet();

  ## Bernouilli Model
  my %bg_suffix_proba = $self->getPrior();

  my %alphabetNb =();
  foreach my $i (0..$#alphabet){
    $alphabetNb{$alphabet[$i]} = $i;
  }

  my %score_proba = ();
  $score_proba{0} = 1; ## Initialize the score probabilities

  ################################################################
  ## Compute the distribution of scores
  for my $c (0..($ncol-1)) {
    &RSAT::message::TimeWarn("Computing weight probabilities for column", $c."/".($ncol-1)) if ($main::verbose >= 4);
    my %current_score_proba = ();

    foreach my $suffix (@alphabet) {
      ## get frequency of the suffix, under matrix model
      my $r = $alphabetNb{$suffix};
      my $suffix_freq_M = $scores[$c][$r];

      if ($suffix_freq_M <= 0) {
	&RSAT::error::FatalError("The matrix contains cells with null values, which induces infinite values for the weight score. To compute score distribution, you need to specify a pseudo-weight.");
      }

      ## get prior frequencies (bg model)
      my $suffix_proba_B = $bg_suffix_proba{$suffix};
#
#      &RSAT::message::Debug("suffix_freq_M", $suffix_freq_M,
#			    "suffix_proba_B", $suffix_proba_B,
#			    "info_log_base", $info_log_base,
#			    "info_log_denominator", $info_log_denominator) if ($main::verbose >= 5);

      ## score
      my $curr_score = log($suffix_freq_M/$suffix_proba_B)/$info_log_denominator; # Beware here, log is ln !!!

      ## discretisation of the scores
      $curr_score = sprintf($score_format_calc, $curr_score);

 #     &RSAT::message::Debug("letter",$suffix,"score",$curr_score) if ($main::verbose >= 5);

      for my $prev_score (keys %score_proba) {
	my $current_score = sprintf($score_format_calc, $prev_score + $curr_score);
	$current_score_proba{$current_score} += $score_proba{$prev_score}*$bg_suffix_proba{$suffix};
      }
    }

    %score_proba = %current_score_proba;
  }

# round the scores to the user-chosen decimals
my %score_proba_decimals;
for my $score (keys %score_proba) {
	my $score_decimals = sprintf($score_format,$score);
	$score_decimals =~ s/^-(0\.0+)$/$1/; ## Suppress the difference between -0.0 and +0.0 after the rounding
	$score_proba_decimals{$score_decimals} += $score_proba{$score};
	}
%score_proba = %score_proba_decimals;

#    my @row = &RSAT::matrix::get_column($c+1, $nrow, @matrix);
#    my @row_scores = &RSAT::matrix::get_column($c+1, $nrow, @scores);
#    my %current_score_proba = ();
#    for my $r (0..($nrow-1)) {
#      my $letter = $alphabet[$r];
#      my $prior = $prior{$letter};
#      my $residue_score = $scores[$c][$r];
##      $residue_score_round = sprintf($score_format, $residue_score);
#      for my $prev_score (keys %score_proba) {
#	my $current_score = sprintf($score_format, $prev_score + $residue_score);
#	$current_score_proba{$current_score} +=
#	  $score_proba{$prev_score}*$prior;
##	&RSAT::message::Debug("col=".$c, "row=".$r, $letter, $prior, $residue_score,
#			      "prev_score",$prev_score,
#			      "current_score", $current_score,
#			     ) if ($main::verbose >= 10);

 #     }
 #   }

#    &RSAT::message::TimeWarn("calcTheorDistrib()", "column", ($c+1)."/".$ncol,
#			     "prev scores: ", scalar(keys(%score_proba)),
#			     "current scores:", scalar(keys(%current_score_proba)),
#			    ) if (($main::verbose >= 4) || ($decimals >= 3));
 #   %score_proba = %current_score_proba;
 # }


  ## Calculate the sorted list of score values
  my $score_proba_cum = 0;
  my %score_proba_cum = ();
  my @sorted_scores;
  my @sorted_scores_inv;
  if ($score_type eq "weights") {
	  ## take all possible weights between the min and max values
	  #     my $min_score = &RSAT::stats::min(keys(%score_proba));
	  #     my $max_score = &RSAT::stats::max(keys(%score_proba));
	  #     my ($Wmin, $Wmax) = $self->weight_range();
	  #     ## Round the min and max scores
	  #     $Wmin = &RSAT::util::trim(sprintf("${score_format}", $Wmin));
	  #     $Wmax = &RSAT::util::trim(sprintf("${score_format}", $Wmax));
	  #     my $distrib_min = &RSAT::stats::min($Wmin, $min_score);
	  #     my $distrib_max = &RSAT::stats::max($Wmax, $max_score);

	  my $distrib_min= &RSAT::stats::min(keys(%score_proba));
	  my $distrib_max= &RSAT::stats::max(keys(%score_proba));

	  &RSAT::message::Debug("theor distrib min",$distrib_min,"theor distrib max",$distrib_max) if ($main::verbose >= 5);

	  my $break_amplif=(10**$decimals);
	  my $break_min = sprintf("%d", $break_amplif*$distrib_min)-1;
	  my $break_max = sprintf("%d", $break_amplif*$distrib_max)+1;
	  foreach my $break ($break_min..$break_max) {
		  my $score = sprintf($score_format, $break/$break_amplif);
		  push @sorted_scores, $score;
		  unshift @sorted_scores_inv, $score;
		  #      &RSAT::message::Debug("BREAKS", $break_min, $break_max, $break_amplif, $break, $score) if ($main::verbose >= 10);
	  }
  } else {
	  @sorted_scores = sort {$a <=> $b} (keys (%score_proba));
  }

  ## Fill in intermediate score values, for which no score was calculated
  ## This prevents from having missing values due to roundings
  my $distrib_min = $sorted_scores[0];
  my $distrib_max = $sorted_scores[$#sorted_scores];
  my @sorted_all_scores = ();
  for (my $score = $distrib_min; $score <= $distrib_max; $score+=1/(10**$decimals)) {
		$score = sprintf($score_format, $score);
		push(@sorted_all_scores,$score) ;
		if (!defined($score_proba{$score})) {
		  $score_proba{$score}="NA";
	  }
	}
	@sorted_scores =  @sorted_all_scores;
	@sorted_scores_inv = sort {$b <=> $a} (keys (%score_proba));

  ## Compute the cumulative distribution
  foreach my $score (@sorted_scores) {
	  if (&RSAT::util::IsReal($score_proba{$score})) {
		  $score_proba_cum += $score_proba{$score};
	  }
	  $score_proba_cum{$score} = $score_proba_cum;
  }

  ## Compute the inverse cumulative distribution
  my $score_inv_cum_proba = 0;
  my %score_inv_cum_proba = ();
  foreach my $score (@sorted_scores_inv) {
    if (&RSAT::util::IsReal($score_proba{$score})) {
      $score_inv_cum_proba += $score_proba{$score};
    }
    $score_inv_cum_proba{$score} = $score_inv_cum_proba;
  }

  ## Tricky way to circumvent a problem of numerical approximation: in
  ## some cases, the computed distrib proba does not contain the
  ## highest weight value, but its maximum is close to it. To
  ## circumvent this, we assign the highest non-null proba value.
  my $proba = 0;
  my $inv_cum_proba = 0;
  my $s = -1;
  do {
    $s++;
    my $score = $sorted_scores_inv[$s];
    $proba = $score_inv_cum_proba{$score};
    $inv_cum_proba = $score_inv_cum_proba{$score};
  } until (($proba > 0) || ($s >= $#sorted_scores_inv));
  if ($s < 5){
    for my $i (0..($s-1)) {
      my $score = $sorted_scores_inv[$i];
      $score_proba{$score} = $proba;
      $score_inv_cum_proba{$score} = $inv_cum_proba;
      &RSAT::message::Debug("Fixing the tail of", $score_type,"distribution for score",
			    $i."/".$s, $score, $score_proba{$score}, $score_inv_cum_proba{$score}) if ($main::verbose >= 4);
    }
  }

  ## Assign the score distributions to the matrix
  $self->set_hash_attribute($score_type."_proba", %score_proba);
  $self->force_attribute($score_type."_proba_specified", 1);
  $self->set_hash_attribute($score_type."_cum_proba", %score_proba_cum);
  $self->force_attribute($score_type."_cum_proba_specified", 1);
  $self->set_hash_attribute($score_type."_inv_cum_proba", %score_inv_cum_proba);
  $self->force_attribute($score_type."_inv_cum_proba_specified", 1);
}

################################################################

=pod

=item B<calcTheorScoreDistribMarkov>

Calculates the theorical distribution of weights probabilities based on
a background model with Markov order > 0 .

=cut
sub calcTheorScoreDistribMarkov {
  my ($self) = @_;
  my $score_type = "weights";

  ################################################################
  ## This parameter drastically affects the speed of computation By
  ## reducing the score to 2 decimals, the nmber of possible scors is
  ## reduced to ~5000 for a typical weight matrix
  ## This prevents the comptation time to increase exponentially with
  ## the matrix width.
  my $decimals = $self->get_attribute("decimals");
  my $score_format = "%.${decimals}f";
  my $score_format_calc = "%.".(${decimals}+1)."f";

  ################################################################
  ## For Markov models, we don't work with a weight matirx, but we
  ## treat separately the PSSM frequencies, and the transition
  ## frequencies of the bg model.

  my @scores = $self->getFrequencies();

  ## Markov Model
  my $bg_model = $self->getMarkovModel();
  my $order = $bg_model->get_attribute("order");

  &RSAT::message::TimeWarn("Calculating theoretical distribution of", $score_type,
			   "Background Markov Model order:".$order,
			   "matrix", $self->get_attribute("name"),
			   "Precision: ".$decimals." decimals",
			  ) if ($main::verbose >= 4);

  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @alphabet = $self->getAlphabet();

  my %alphabetNb =();
  foreach my $i (0..$#alphabet) {
    $alphabetNb{$alphabet[$i]} = $i;
  }

  ################################################################
  ## Initialize the score probabilities with the first word of Markov
  ## order size
  my %distrib_proba =();
  my $initial_col = $order-1;
  my $p = 0;
  my @prefixes = $bg_model->get_prefixes();
  my $prefix_nb = scalar(@prefixes);
  &RSAT::message::TimeWarn("Computing weight probabilities for all prefixes")
    if ($main::verbose >= 4);
  foreach my $initial_prefix (@prefixes) {
    $p++;
    &RSAT::message::Debug("Computing weight probabilities for prefix", $initial_prefix, $p."/".$prefix_nb)
      if ($main::verbose >= 4);
    $prefixes{$initial_prefix} = 1;
    ## get frequency of the prefix, under matrix model
    ## treat separately each letter of the prefix
    my $prefix_freq_M = 1;
    foreach my $c (0..$initial_col) {
      my $letter = substr($initial_prefix, $c,1);
      my $r = $alphabetNb{$letter};
      $prefix_freq_M *= $scores[$c][$r];
#      &RSAT::message::Debug("prefix:",$initial_prefix,"c",$c,"letter",$letter,"nb",$r,"score",$scores[$c][$r]) if ($main::verbose >= 10);
    }

    ## get frequency of the prefix, under bg model
    my $prefix_freq_B = $bg_model->{prefix_proba}->{$initial_prefix};

    ## score
    my $score_init;
    if (($prefix_freq_M == 0) || ($prefix_freq_B == 0)) {
      $score_init = 0;
    } else {
      $score_init = log($prefix_freq_M/$prefix_freq_B)/$info_log_denominator; # Beware here, log is ln !!!
    }

    ## discretisation of the scores
    $score_init = sprintf($score_format_calc, $score_init);

    ## proba
    if ($distrib_proba{$score_init}->{$initial_prefix}) {
      $distrib_proba{$score_init}->{$initial_prefix} += $prefix_freq_B;
    } else {
      $distrib_proba{$score_init}->{$initial_prefix} = $prefix_freq_B;
    }
#    &RSAT::message::Debug($initial_prefix,"\tscore_init = log( $prefix_freq_M / $prefix_freq_B)\t= $score_init\n",
#			  "\tproba\t = $prefix_freq_B\n") if ($main::verbose >= 10);
  }

  ################################################################
  ## Iteration on remaining columns of the matrix
  foreach my $c ($order..($ncol-1)) {
    &RSAT::message::TimeWarn("Computing weight probabilities for column", $c."/".($ncol-1)) if ($main::verbose >= 4);

    my @curr_prefix = sort(keys(%prefixes));
    my @previous_scores = (keys(%distrib_proba));

    %prefixes =();
    my %current_distrib_proba =();

    ## iterate on all possible prefixes
    foreach my $prefix (@curr_prefix) {
#      &RSAT::message::Debug("col",$c,"prefix",$prefix) if ($main::verbose >= 10);
      foreach my $suffix (@alphabet) {

	## get frequency of the suffix, under matrix model
	my $r = $alphabetNb{$suffix};
	my $suffix_freq_M = $scores[$c][$r];

	## get transition frequency, from prefix to suffix (bg model)
	my $suffix_transition_B = $bg_model->{transitions}->{$prefix}->{$suffix};

	## score
	my $curr_score = log($suffix_freq_M/$suffix_transition_B)/$info_log_denominator; # Beware here, log is ln !!!
	## discretisation of the scores
	$curr_score = sprintf($score_format_calc, $curr_score);

#	&RSAT::message::Debug("$prefix->$suffix","curr_score = log( $suffix_freq_M / $suffix_transition_B ) = $curr_score") if ($main::verbose >= 10);
	foreach my $prev_score (@previous_scores) {

	  if ($distrib_proba{$prev_score}->{$prefix}) {

	    ## new scores for this position
	    my $sum_score = $curr_score + $prev_score;
	    $sum_score = sprintf($score_format_calc, $sum_score);

	    ## proba
	    ## summing (in fact, multiplying) with proba of previous state (AND)
	    my $curr_proba = $distrib_proba{$prev_score}->{$prefix} * $suffix_transition_B;

	    ## prefix for next iteration
	    my $current_word = $prefix.$suffix;
	    my $prefix_tag = substr($current_word, -$order);
	    $prefixes{$prefix_tag} = 1;

	    if ($current_distrib_proba{$sum_score}->{$prefix_tag}) {
	      $current_distrib_proba{$sum_score}->{$prefix_tag} += $curr_proba;
	    } else {
	      $current_distrib_proba{$sum_score}->{$prefix_tag} = $curr_proba;
	    }
#	    &RSAT::message::Debug("\tprefix", $prefix,"prev_score",$prev_score ,"sum_score", $sum_score ,
#				  "proba",$curr_proba) if ($main::verbose >= 10);
	  }
	}
      }
    }

    %distrib_proba = ();
    %distrib_proba = %current_distrib_proba;
  }

  ## finalisation phase
  my %score_proba =();
  $proba_sum = 0;
  foreach my $score (keys (%distrib_proba)) {
    foreach my $prefix (keys(%{$distrib_proba{$score}})) {
      if ($score_proba{$score}) {
	$score_proba{$score} += $distrib_proba{$score}->{$prefix};
      } else {
	$score_proba{$score} = $distrib_proba{$score}->{$prefix};
      }
      $proba_sum += $distrib_proba{$score}->{$prefix};
    }
  }

#  &RSAT::message::Debug("proba sum", $proba_sum) if ($main::verbose >= 10);

  # round the scores to the user-chosen decimals
  my %score_proba_decimals;
  for my $score (keys %score_proba) {
    my $score_decimals = sprintf($score_format,$score);
    $score_decimals =~ s/^-(0\.0+)$/$1/; ## Suppress the difference between -0.0 and +0.0 after the rounding
    $score_proba_decimals{$score_decimals} += $score_proba{$score};
  }
  %score_proba = %score_proba_decimals;

  ## Calculate the sorted list of score values
  my $score_proba_cum = 0;
  my %score_proba_cum = ();
  my @sorted_scores;
  my @sorted_scores_inv;
  if ($score_type eq "weights") {
    ## take all possible weights between the min and max values
    #     my $min_score = &RSAT::stats::min(keys(%score_proba));
    #     my $max_score = &RSAT::stats::max(keys(%score_proba));
    #   #####  my ($Wmin, $Wmax) = $self->weight_range();
    #     ## Round the min and max scores
    #     $Wmin = &RSAT::util::trim(sprintf("${score_format}", $Wmin));
    #     $Wmax = &RSAT::util::trim(sprintf("${score_format}", $Wmax));
    #     my $distrib_min = &RSAT::stats::min($Wmin, $min_score);
    #     my $distrib_max = &RSAT::stats::max($Wmax, $max_score);

    my $distrib_min = &RSAT::stats::min(keys(%score_proba));
    my $distrib_max = &RSAT::stats::max(keys(%score_proba));
#    &RSAT::message::Debug("theor distrib min",$distrib_min,"theor distrib max",$distrib_max) if ($main::verbose >= 10);

    my $break_amplif=(10**$decimals);
    my $break_min = sprintf("%d", $break_amplif*$distrib_min)-1;
    my $break_max = sprintf("%d", $break_amplif*$distrib_max)+1;
    foreach my $break ($break_min..$break_max) {
      my $score = sprintf($score_format, $break/$break_amplif);
      push @sorted_scores, $score;
      unshift @sorted_scores_inv, $score;
#      &RSAT::message::Debug("BREAKS", $break_min, $break_max, $break_amplif, $break, $score) if ($main::verbose >= 10);
    }
  } else {
    @sorted_scores = sort {$a <=> $b} (keys (%score_proba));
  }

  ## Fill in intermediate score values, for which no score was calculated
  ## This prevents from having missing values due to roundings
  my $distrib_min = $sorted_scores[0];
  my $distrib_max = $sorted_scores[$#sorted_scores];
  my @sorted_all_scores = ();
  for (my $score = $distrib_min; $score <= $distrib_max; $score+=1/(10**$decimals)) {
    $score = sprintf($score_format, $score);
    push(@sorted_all_scores,$score) ;
    if (!defined($score_proba{$score})) {
      $score_proba{$score}="NA";
    }
  }
  @sorted_scores =  @sorted_all_scores;
  @sorted_scores_inv = sort {$b <=> $a} (keys (%score_proba));

  ## Compute the cumulative distribution
  foreach my $score (@sorted_scores) {
    if (&RSAT::util::IsReal($score_proba{$score})) {
      $score_proba_cum += $score_proba{$score};
    }
    $score_proba_cum{$score} = $score_proba_cum;
  }

  ## Compute the inverse cumulative distribution
  my $score_inv_cum_proba = 0;
  my %score_inv_cum_proba = ();
  foreach my $score (@sorted_scores_inv) {
    if (&RSAT::util::IsReal($score_proba{$score})) {
      $score_inv_cum_proba += $score_proba{$score};
    }
    $score_inv_cum_proba{$score} = $score_inv_cum_proba;
  }

  ## Tricky way to circumvent a problem of numerical approximation: in
  ## some cases, the computed distrib proba does not contain the
  ## highest weight value, but its maximum is close to it. To
  ## circumvent this, we assign the highest non-null proba value.
  my $proba = 0;
  my $inv_cum_proba = 0;
  my $s = -1;
  do {
    $s++;
    my $score = $sorted_scores_inv[$s];
    $proba = $score_inv_cum_proba{$score};
    $inv_cum_proba = $score_inv_cum_proba{$score};
  } until (($proba > 0) || ($s >= $#sorted_scores_inv));
  if ($s < 5) {
    for my $i (0..($s-1)) {
      my $score = $sorted_scores_inv[$i];
      $score_proba{$score} = $proba;
      $score_inv_cum_proba{$score} = $inv_cum_proba;
      &RSAT::message::Debug("Fixing the tail of", $score_type,"distribution for score",
			    $i."/".$s, $score, $score_proba{$score}, $score_inv_cum_proba{$score}) if ($main::verbose >= 4);
    }
  }

  ## Assign the score distributions to the matrix
  $self->set_hash_attribute($score_type."_proba", %score_proba);
  $self->force_attribute($score_type."_proba_specified", 1);
  $self->set_hash_attribute($score_type."_cum_proba", %score_proba_cum);
  $self->force_attribute($score_type."_cum_proba_specified", 1);
  $self->set_hash_attribute($score_type."_inv_cum_proba", %score_inv_cum_proba);
  $self->force_attribute($score_type."_inv_cum_proba_specified", 1);
}


################################################################

=pod

=item getTheorScoreDistrib()

Return the weight matrix

Usage:

=over

=item density function

my %weight_proba = $matrix->getTheorScoreDistrib("weights");

=item cumulative density function (CDF)

my %weight_proba_cum = $matrix->getTheorScoreDistrib("weights", "cum");

=item inverse cumulative density function (iCDF)

my %weight_proba_invcum = $matrix->getTheorScoreDistrib("weights", "inv_cum");

=back

=cut
sub getTheorScoreDistrib {
  my ($self, $score_type, $distrib_type) = @_;

  $score_type = $score_type || "weights";
  my $distrib_key = $score_type;
  if ($distrib_type) {
    $distrib_key .= "_".$distrib_type;
  }
  $distrib_key .= "_proba";

  ## Check if the distribution has aleady been calculated
  unless ($self->get_attribute($distrib_key."_specified")) {
    $self->calcTheorScoreDistrib($score_type);
  }

  &RSAT::message::Info("Returning distribution", $distrib_key) if ($main::verbose >= 4);
  return %{$self->{$distrib_key}};
}

################################################################

=pod

=item makeLogo()

Return the logo from the matrix

Usage:

  my @logo_files = $matrix->makeLogo($logo_basename,\@logo_formats,$logo_dir, $logo_opt, $rev_compl);

=cut
sub makeLogo{
  my ($self,$logo_basename,$logo_formats,$logo_dir, $logo_options, $rev_compl) = @_;

  ## We need an ID -> if not defined, use the consensus
  my $ac = $self->get_attribute("accession");
  my $id = $self->get_attribute("id");
  unless ($id) {
    $self->calcConsensus();
    $id = $self->get_attribute("consensus.IUPAC");
    $self->force_attribute("id", $id);
  }

  unless ($logo_basename) {
    $logo_basename = $accession || $id;
  }

  my $ncol = $self->ncol();

  &RSAT::util::CheckOutDir($logo_dir) if ($logo_dir);

  ## Make sure there is at least one logo format
  my (@logo_formats) = @{$logo_formats};
  if (scalar(@logo_formats) == 0) {
    push @logo_formats, "png";
  }

  ## Create a file with fake sequences having the same residue composition as the matrix
  my ($fake_seq_file,$seq_number) = $self->fake_seq_from_matrix($logo_dir, $rev_compl);

  &RSAT::message::Debug("makeLogo", $id, $logo_dir, $seq_number, $rev_compl, "fake sequences", $fake_seq_file)
    if ($main::verbose >= 5);

  ## Logo title indicates matrix ID, name
  my $logo_title = &RSAT::util::ShortFileName($id);
  if (my $ac = $self->get_attribute("ac")) {
    if ($ac ne $id) {
      $logo_title .= " ".&RSAT::util::ShortFileName($ac);
    }
  }
  if (my $name = $self->get_attribute("name")) {
    if ($name ne $id) {
      $logo_title .= " ".&RSAT::util::ShortFileName($name);
    }
  }


  if ($rev_compl) {
    $logo_title .= "  RC";
  }
  my $max_logo_title=$ncol*3;
  if (length($logo_title) > $max_logo_title) {
    $logo_title = "...".substr($logo_title, -$max_logo_title);
    &RSAT::message::Warning("truncating logo title", $logo_title) if ($main::verbose >= 4);
  }

  ## Legend on the X axis indicates number of sites
  my $logo_info = $seq_number." sites";

  ## Run seqlogo to generate the logo(s)
  my $seqlogo_path = &RSAT::server::GetProgramPath("seqlogo");
  foreach my $logo_format (@logo_formats){
#    my $seqlogo_path = $ENV{seqlogo} || $ENV{RSAT}."/bin/seqlogo";
    $seqlogo_path = &RSAT::util::trim($seqlogo_path);
    unless (-e $seqlogo_path) {
      &RSAT::message::Warning("Cannot generate the sequence logo because the program seqlogo is not found in the expected path",
			      $seqlogo_path,
			      "Please install seqlogo in the recommended location.");
      return;
    }

    ## Prepare the seqlogo command
    my $logo_cmd = $seqlogo_path;
    $logo_cmd.= " -f ".$fake_seq_file;
    $logo_cmd .= " -F ".$logo_format." -c -Y -n -a -b -k 1 -M -e ";
    $logo_cmd .= " -w ".$ncol unless ($logo_options =~ /\-w /);
    $logo_cmd .= " -x '".$logo_info."'";
    $logo_cmd .= " -h 5 " unless ($logo_options =~ /\-h /);
#    $logo_cmd .= " -e -M";
    $logo_cmd .= " ".$logo_options;
    $logo_cmd .= " -o ". $logo_basename;
    $logo_cmd .= " -t '".$logo_title."'";
    &RSAT::message::Info("Logo options: ".$logo_options) if ($main::verbose >= 5);
    &RSAT::message::Info("Logo cmd: ".$logo_cmd) if ($main::verbose >= 5);

    ## Run seqlogo with specific parameters for the &doit() procedure
    my $logo_dry = 0;
    my $logo_die = 0;
    my $logo_verbose = 0;
    my $logo_batch = 0;
    my $logo_job_prefix = "";
    &RSAT::util::doit($logo_cmd,$logo_dry,$logo_die,$logo_verbose,$logo_prefix);

    my $logo_file = $logo_basename.".".$logo_format;
    push @logo_files, $logo_file;
    &RSAT::message::Info("matrix", $self->get_attribute("id"), "Logo file", $logo_file) if ($main::verbose >= 4);
    ## Remove the fake sequences, not necessary anymore
    &RSAT::server::DelayedRemoval($fake_seq_file);
#    unlink ($fake_seq_file); ## The file removal  makes a problem that I don't understand
  }
  return(@logo_files);
}

################################################################
## This method is somewat artificial: it prints fake sequences that
## respect the residue counts of the matrix, in order to generate a
## logo with seqlogo.
#
## The problem is that seqlogo takes as input a sequence set, instead
## of a matrix. In the near future we should use another
## logo-generating program (for example enologos, which is more
## flexible, see http://biodev.hgen.pitt.edu/enologos/).
##
sub fake_seq_from_matrix {
  my ($self,$seq_dir, $rev_compl) = @_;
  &RSAT::message::Debug("&RSAT::matrix::fake_seq_from_matrix", "dir=".$seq_dir, "rev_compl=".$rev_compl) if ($main::verbose >= 5);

  my $null_residue = "n"; ##  to fill up sequences for matrices having columns with different number of residues

  my $nb_col = $self->ncol();
  my $nb_row = $self->nrow();
  @matrix = @{$self->{table}};

  ### Check if the sum of all column identical
  my @col_sum = col_sum($nb_row,$nb_col,@matrix);
  my $max_col_sum = &RSAT::stats::max(@col_sum);
  my @null_residues = ();
  for my $i (0..$#col_sum) {
    $null_residues[$i] = $max_col_sum - $col_sum[$i];
#    if ($null_residues[$i] > 0) {
#      &RSAT::message::Warning("The sums of counts per column must all be equal in order to make logo.");
#    }
  }
  my $seq_number = $max_col_sum;

  ################################################################
  ## Create a vector of sequences representing the letters per column
  my @letters_at_column = ();
  for my $c (0..$nb_col-1) {
    my $i=0;
    my $null_residue_nb = $max_col_sum; ## counter for the null residues in the current column
    foreach my $letter ($self->getAlphabet()) {
      ##    foreach my $letter ("A","C","G","T") {
      my $counts = &RSAT::util::round($matrix[$c][$i]); ## round the number in order to support matrices with decimal values
      $null_residue_nb -= $counts;
      $letters_at_column[$c] .= $letter x $counts;
#      &RSAT::message::Debug("&fake_seq_from_matrix()", $letter, "col=".$c, "row=".$i, $counts) if ($main::verbose >= 10);
      $i++;
    }
    $letters_at_column[$c] .= $null_residue x $null_residue_nb;
#    &RSAT::message::Debug("&fake_seq_from_matrix()", "Column-letters", $letters_at_column[$c]) if ($main::verbose >= 10);
  }


  ## Print sequences
  my @intermediate = ();
  for my $col_seq (@letters_at_column) {
    my @residues = split ("",$col_seq);
    push @intermediate, \@residues;
  }
  my @seqs=();
  for my $residue (0..$seq_number-1) {
    my $fake_seq;
    for my $array (@intermediate) {
      $fake_seq .= $array->[$residue];
    }
    $fake_seq = &RSAT::SeqUtil::ReverseComplement($fake_seq) if ($rev_compl);
    &RSAT::message::Debug("&RSAT::matrix::fake_seq_from_matrix", "Fake sequence", $col_seq) if ($main::verbose >= 6);
    push @seqs, $fake_seq;
  }
  &RSAT::message::Debug("Fake sequences from matrix :\n;",join ("\n;\t",@seqs)) if ($main::verbose >= 4);

  ## create a temporary sequence file which will be deleted after logo creation
  my $tmp_seq_file = &RSAT::util::make_temp_file($seq_prefix, $self->get_attribute("id"));
  my $seq_handle = &RSAT::util::OpenOutputFile($tmp_seq_file);
  print $seq_handle join("\n",@seqs)."\n";
#  my $current_id = 0;
#  foreach my $current_seq (@seqs) {
#      $current_id++;
#      &main::PrintNextSequence($seq_handle, "fasta", 0, $current_seq, $current_id);
#  }
#  &RSAT::message::Debug("Fake sequences stored in temp file\n", $tmp_seq_file) if ($main::verbose >= 5);
  return ($tmp_seq_file,$seq_number);
}


=pod

=item B<reverse_complement>

Replace the matrix by its reverse complement.

If require, re-compute the frequency, weight and information content
matrice.

Usage: $matrix->reverse_complment();

=cut
sub reverse_complement {
  my ($self) = @_;
  my @ori_matrix = $self->getMatrix();
  my @rc_matrix = ();
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @alphabet = $self->getAlphabet();

  ## Index rows by residue
  my %row = ();
  foreach my $r (0..$#alphabet) {
    $row{lc($alphabet[$r])} = $r;
  }

  ## Reverse complement residues
  my %rc = ('a'=>'t',
	   'c'=>'g',
	   'g'=>'c',
	   't'=>'a');

  ## reverse each row (residue)
  foreach my $r (0..($nrow-1)) {
    my $res = lc($alphabet[$r]);
    my $rc = $rc{$res};
    my $rc_row = $row{$rc};
    foreach my $c (0..($ncol-1)) {
      my $rc_col= $ncol-1-$c;
      my $occ = $ori_matrix[$c][$r];
      $rc_matrix[$rc_col][$rc_row] = $ori_matrix[$c][$r];
    }
  }
  $self->setMatrix ($nrow, $ncol, @rc_matrix);

  ## Update the dependent tables
  if (($self->get_attribute("frequencies_specified")) || ($self->get_attribute("crudeFrequencies_specified"))) {
    $self->calcFrequencies();
  }
  $self->calcWeights() if ($self->get_attribute("weights_specified"));
  $self->calcInformation() if ($self->get_attribute("information_specified"));
  $self->calcConsensus() if ($self->get_attribute("consensus_specified"));
}

=pod

=item I<calcCountRC>

Compute the reverse complement of the count matrix, and
store it in a separate attribute (table) named countRC.

The reverse complement of the count matrix is used (uder others) for
displaying matrix alignments.

In principle, the method &calcCountRC() should be
called only once during the execution of the program. After the first
computation, the RC matrix can be retrieved multiple times with the
method &getCountRC().

=cut

sub calcCountRC {
  my ($self) = @_;
  my @ori_matrix = $self->getMatrix();
  my @rc_matrix = ();
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @alphabet = $self->getAlphabet();

  ## Index rows by residue
  my %row = ();
  foreach my $r (0..$#alphabet) {
    $row{lc($alphabet[$r])} = $r;
  }

  ## Reverse complement residues
  my %rc = ('a'=>'t',
	   'c'=>'g',
	   'g'=>'c',
	   't'=>'a');

  ## reverse each row (residue)
  foreach my $r (0..($nrow-1)) {
    my $res = lc($alphabet[$r]);
    my $rc = $rc{$res};
    my $rc_row = $row{$rc};
    foreach my $c (0..($ncol-1)) {
      my $rc_col= $ncol-1-$c;
      my $occ = $ori_matrix[$c][$r];
      $rc_matrix[$rc_col][$rc_row] = $ori_matrix[$c][$r];
    }
  }
  @{$self->{countRC}} = @rc_matrix;

#  &RSAT::message::Debug("Computed countRC", $self->get_attribute("id"), join(", ", @rc_matrix)) if ($main::verbose >= 10);
  $self->force_attribute("countRC_specified", 1);
}


################################################################

=pod

=item getCountRC()

Return the reverse complement of the count matrix.

This is used for displaying matrix alignments.

The first time this method it called, the RC of the count matrix is
computed with calcCountRC(), and stored in the attribute
"countRC". After this, the method simply return this attribute.

=cut
sub getCountRC {
    my ($self) = @_;
    unless ($self->get_attribute("countRC_specified")) {
	$self->calcCountRC();
    }
    return @{$self->{countRC}};
}



=pod

=item I<calcCrudeFreqRC>

Compute the reverse complement of the crude frequency matrix, and
store it in a separate attribute (table) named crudeFreqRC.

This is useful for two-strands alignments, where one necessitates both
the direct and the reverse complementary matrix at each step (shift) of
the alignment.

In principle, the method &calcCrudeFreqRC() should be
called only once during the execution of the program. After the first
computation, the RC matrix can be retrieved multiple times with the
method &getCrudeFreqRC().

=cut

sub calcCrudeFreqRC {
  my ($self) = @_;
  my @ori_matrix =  $self->getCrudeFrequencies();
  my @rc_matrix = ();
  my $nrow = $self->nrow();
  my $ncol = $self->ncol();
  my @alphabet = $self->getAlphabet();

  ## Index rows by residue
  my %row = ();
  foreach my $r (0..$#alphabet) {
    $row{lc($alphabet[$r])} = $r;
  }

  ## Reverse complement residues
  my %rc = ('a'=>'t',
	   'c'=>'g',
	   'g'=>'c',
	   't'=>'a');

  ## reverse each row (residue)
  foreach my $r (0..($nrow-1)) {
    my $res = lc($alphabet[$r]);
    my $rc = $rc{$res};
    my $rc_row = $row{$rc};
    foreach my $c (0..($ncol-1)) {
      my $rc_col= $ncol-1-$c;
      my $occ = $ori_matrix[$c][$r];
      $rc_matrix[$rc_col][$rc_row] = $ori_matrix[$c][$r];
    }
  }
  @{$self->{crudeFreqRC}} = @rc_matrix;

  $self->force_attribute("crudeFreqRC_specified", 1);
}


################################################################

=pod

=item getCrudeFreqRC()

Return the reverse complement of the crude frequency matrix.

This is useful for two-strands alignments, where one necessitates both
the direct and the reverse complementary matrix at each step (shift) of
the alignment.

The first time this method it called, the RC of the crude frequency
matrix is computed with calcCrudeFreqRC(), and stored in the attribute
"crudeFreqRC". After this, the method simply return this attribute.

=cut
sub getCrudeFreqRC {
    my ($self) = @_;
    unless ($self->get_attribute("crudeFreqRC_specified")) {
	$self->calcCrudeFreqRC();
    }
    return @{$self->{crudeFreqRC}};
}

=pod

=item I<link_button_TOMTOM>

Return a HTML form for sending the matrix to TOMTOM.

=cut
sub link_button_TOMTOM {
    my ($self) = @_;
#    $self->force_attribute("margins", 0);
    my $matrix_content = $self->toString(sep=>"\t",
					 type=>"counts",
					 format=>'tab',
					 no_comment=>1
					);
    $matrix_content =~ s|//||g; ## Suppress record separator
    $matrix_content =~ s|^;.*\n||g; ## Suppress comments
    my $button = "<form method='post' target='_blank' action='http://meme.nbcr.net/meme4/cgi-bin/tomtom.cgi'>";
    $button .= "<input type='hidden' name='query' value='${matrix_content}'>";
    $button .= "<input type='hidden' name='DIST' value='pearson'>";
    $button .= "<input type='hidden' name='target_db' value='JASPAR_CORE_2008'>";
    $button .= "<input type='submit' value='TOMTOM'>";
    $button .= "</form>\n";
    return $button;
}




return 1;


__END__

=pod

=back


