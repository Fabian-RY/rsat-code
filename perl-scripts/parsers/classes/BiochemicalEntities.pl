

##########################################################################################
################################# BIOCHEMICAL ENTITIES ###################################
##########################################################################################

package PFBP::BiochemicalEntity;
{
  @ISA = qw ( PFBP::DatabaseObject );
  ### this is a super-class for all the biochemical entities
  ### it should be a method class only, instantiation necessitates 
  ### to specify the sub-class
  %_attribute_cardinality = (xref=>"EXPANDED");
}

package PFBP::Compound;
{
    @ISA = qw ( PFBP::BiochemicalEntity );
      ### class attributes
    $_count = 0;
    $_prefix = "comp_N";
    @_objects = ();
    %_name_index = ();
    %_id_index = ();
    %_attribute_count = ();
    %_attribute_cardinality = (id=>"SCALAR",
			       names=>"ARRAY",
			       formula=>"SCALAR",
			       description=>"SCALAR",
			       source=>"SCALAR");
    
}

package PFBP::Polypeptide;
{
  @ISA = qw ( PFBP::BiochemicalEntity );
  ### class attributes
  $_count = 0;
  $_prefix = "ppep_";
  @_objects = ();
  %_name_index = ();
  %_id_index = ();
  %_attribute_count = ();
  %_attribute_cardinality = (id=>"SCALAR",
		      names=>"ARRAY",
		      gene=>"SCALAR",
		      swissprot_acs=>"ARRAY",
		      swissprot_ids=>"ARRAY",
		      source=>"SCALAR");
}

package PFBP::ProteinComplex;
{
  @ISA = qw ( PFBP::BiochemicalEntity );
  ### class attributes
  $_count = 0;
  $_prefix = "ppep_";
  @_objects = ();
  %_name_index = ();
  %_id_index = ();
  %_attribute_count = ();
  %_attribute_cardinality = (id=>"SCALAR",
		      names=>"ARRAY",
		      source=>"SCALAR");
}

package PFBP::ProteicDomain;
{
  @ISA = qw ( PFBP::BiochemicalEntity );
  ### class attributes
  $_count = 0;
  $_prefix = "pdom_";
  @_objects = ();
  %_name_index = ();
  %_id_index = ();
  %_attribute_count = ();
  %_attribute_cardinality = (id=>"SCALAR",
			     names=>"ARRAY",
			     source=>"SCALAR");
}

package PFBP::Gene;
{
  @ISA = qw ( PFBP::BiochemicalEntity );
  ### class attributes
  $_count = 0;
  $_prefix = "gene_";
  @_objects = ();
  %_name_index = ();
  %_id_index = ();
  %_attribute_count = ();
  %_attribute_cardinality = (id=>"SCALAR",
			     names=>"ARRAY",
			     organism=>"SCALAR",
			     type=>"SCALAR",
			     description=>"SCALAR",
			     chrom_position=>"SCALAR",
			     position=>"SCALAR",
			     chromosome=>"SCALAR",
			     strand=>"SCALAR",
			     start=>"SCALAR",
			     end=>"SCALAR",
			     source=>"SCALAR",
			     xrefs=>"EXPANDED"
			     );


#    ### specific definition for KEGG names
#    ### because they have to be split by lines
#    sub push_attribute {
#        my ($self,$key,$value) = @_;
      
#        if ($key eq "names") {
#  	  my %previous_names = ();
#  	  foreach my $name ($self->get_attribute("names")) {
#  	      $previous_names{$name}++;
#  	  }
#  	  $self->SUPER::push_attribute($key,$value) unless $previous_names{$value};
#        }else {
#  	  $self->SUPER::push_attribute($key,$value);
#        }
#    }
}

package PFBP::Contig; ### for parsing genbank files
{
  @ISA = qw ( PFBP::BiochemicalEntity );
  ### class attributes
  $_count = 0;
  $_prefix = "gene_";
  @_objects = ();
  %_name_index = ();
  %_id_index = ();
  %_attribute_count = ();
  %_attribute_cardinality = (id=>"SCALAR",
			     names=>"ARRAY",
			     organism=>"SCALAR",
			     type=>"SCALAR",
			     xrefs=>"EXPANDED"
			     );
}

return 1;
