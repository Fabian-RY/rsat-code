###############################################################
#
# Class SeqUtil
#
package RSAT::SeqUtil;

use RSAT::GenericObject;
use RSAT::error;
@ISA = qw( RSAT::GenericObject );

### class attributes

=pod

=head1 NAME

    RSAT::SeqUtil

=head1 DESCRIPTION

Abstract class containing a set of methods for trating sequences.

=cut


################################################################
=pod

=item get_accepted_residues()

Returns a hash table with the accepted residues, given the sequence
type (DNA or protein). 

Usage:  my %accepted_residues = &RSAT::SeqUtil::get_accepted_residues($seq_type);

=cut
sub get_accepted_residues {
  my ($seq_type) = @_;
  &RSAT::error::FatalError("The method &RSAT::SeqUtil::get_accepted_residues() requires to specify a sequence type.") 
    unless ($seq_type);

  my @dna_alphabet = qw (a c g t);
  my @protein_alphabet = qw(a c d e f g h i k l m n p q r s t v w y);
  my @alphabet = ();
  my %accepted_residues = ();

  if (lc($seq_type) eq "dna") {
    @alphabet = @dna_alphabet;
  } elsif (lc($seq_type) eq "protein") {
    @alphabet = @protein_alphabet;
  } else {
    &RSAT::error::FatalError("The method &RSAT::SeqUtil::get_accepted_residues()", "Invalid sequence type.", "Supported: dna,protein");
  }

  foreach my $residue (@alphabet) {
    $accepted_residues{$residue} = 0.25;
  }
  
  return(%accepted_residues);
}

################################################################
=pod

=item B<all_possible_oligos>

Generate all possible oligomers for a given alphabet. 

The default alphabet is DNA (a,c,g,t), but alternative alphabet can be
specified by entering the array of letters as second argument.

 Usage: 

    ## All possible oligonucleotides of a given length
    my @oligos = &RSAT::SeqUtil::all_possible_oligos($oligo_length);

    ## All possible oligomers of a given lenth, with a given alphabet
    my @oligos = &RSAT::SeqUtil::all_possible_oligos($oligo_length, @alphabet);

=cut
sub all_possible_oligos {
  my ($len, @alphabet) = @_;
  if (scalar(@alphabet) == 0) {
    @alphabet = qw (a c g t);
  }

  my @oligos = ();
  if  ($len == 1) {
    @oligos = @alphabet;
  } elsif ($len > 1) {
    my @sub_oligos = &RSAT::SeqUtil::all_possible_oligos($len-1, @alphabet);
    foreach my $letter (@alphabet) {
      foreach my $oligo (@sub_oligos) {
	push @oligos, $letter.$oligo;
      }
    }
  }
  &RSAT::message::Info("&all_possible_oligos()", "len", $len, "alphabet", scalar(@alphabet), "oligos", scalar(@oligos)) if ($main::verbose >= 3);
  return @oligos;
}


################################################################
=pod

=item B<ReverseComplement>

Return the reverse complement of a DNA sequence.

Usage: my $rc = &RSAT::SeqUtil::ReverseComplement($seq);

=cut
sub ReverseComplement {
    local($orig_seq) = $_[0];
    $complement = reverse $orig_seq;
    $complement =~ tr/a-z/A-Z/;
    ### simple nucleotides
    $complement =~ s/A/t/g;
    $complement =~ s/T/a/g;
    $complement =~ s/C/g/g;
    $complement =~ s/G/c/g;
    ### degenerate code
    $complement =~ s/R/y/g;
    $complement =~ s/Y/r/g;
    $complement =~ s/M/k/g;
    $complement =~ s/K/m/g;
    $complement =~ s/B/v/g;
    $complement =~ s/V/b/g;
    $complement =~ s/H/d/g;
    $complement =~ s/D/h/g;
    #  $complement =~ s/S/s/g;
    #  $complement =~ s/W/w/g;
    #  $complement =~ s/N/n/g;
    ###  brackets
    $complement =~ s/\[/temp/g;
    $complement =~ s/\]/\[/g;
    $complement =~ s/temp/\]/g;
    $complement =~ tr/a-z/A-Z/;
    ### multiplier
    while (($complement =~ /(\}\d+\{)/) 
	   || ($complement =~ /(\}\d+,\d+\{)/) ) {
	$rev_mul = reverse $1;
	$complement =~ s/$1/$rev_mul/g;
    }
    $complement =~ s/(\{\d+\})(\w)/$2$1/g;
    $complement =~ s/(\{\d+,\d+\})(\w)/$2$1/g;
    $complement =~ s/(\{\d+\})(\[\w+\])/$2$1/g;
    $complement =~ s/(\{\d+,\d+\})(\[\w+\])/$2$1/g;
    return $complement;
}# ReverseComplement


return 1;

__END__
