#!/usr/bin/perl

################################################################
## Connect a RSAT server and get a  list of supported organisms
##
## Usage:
##   perl supported-organisms_client_nostubb.wsdl [server_URL]

use strict;

# import the modules we need for this test; XML::Compile is included on the server
# by default.
use XML::Compile::SOAP11;
use XML::Compile::WSDL11;
use XML::Compile::Transport::SOAPHTTP;


## Specification of the server
#my $server = $ARGV[0] || "http://rsat.bigre.ulb.ac.be/rsat";
my @servers = $ARGV[0] || qw(
			   http://rsat01.biologie.ens.fr/rsa-tools
			   http://rsat.bigre.ulb.ac.be/rsat
			   http://wwwsup.scmbb.ulb.ac.be/rsat
			   http://tagc.univ-mrs.fr/rsa-tools
			   http://embnet.ccg.unam.mx/rsa-tools
			   http://liv.bmc.uu.se/rsa-tools
			   http://localhost/rsat
			   http://anjie.bi.up.ac.za/rsa-tools
			    );

#		 http://rsat01.biologie.ens.fr/rsa-tools

## Query parameters
my $taxon = '';
my $return = 'ID,taxonomy';
my %args = (
	    'taxon' => $taxon,
	    'return'=>$return,
	   );
foreach my $server (@servers) {
  warn "\n";

  eval
    {
      # Retrieving and processing the WSDL
      my $wsdl_url = $server.'/web_services/RSATWS.wsdl';
      warn ("Parsing Web service description from WSDL", "\t", $wsdl_url, "\n");
      my $wsdl  = XML::LibXML->new->parse_file($wsdl_url);
      my $proxy = XML::Compile::WSDL11->new($wsdl);

      ## Compiling the client for supported-organisms
      warn ("Compiling client\n");
      my $client = $proxy->compileClient('supported_organisms');

      # Calling the service and getting the response
      warn ("Sending query to server", "\t", $server, "\n");
#      warn "Getting list of supported organisms from server\t", $server, "\n";
      my $answer = $client->( request => {%args});
      #    print OUT "Answer: ".$answer."\n";

      my $file = "organisms_".$server.".txt";
      $file =~ s|http://||;
      $file =~ s|/|_|g;
      open OUT, ">$file";
      warn "Result stored in file\t", $file, "\n";

      ## Open output file
      # If the response arrived, look for a specific pattern
      # If the pattern is present, return 0 because the test passed.
      # If the result is something else, return 2 to indicate a warning.
      # If no answer has arrived, return 1 to indicate the test failed.
      if ( defined $answer ) {
	print OUT "; Server : ", $server, "\n";
	print OUT "; WSDL : ", $wsdl, "\n";
	print OUT "; Server command : ".$answer->{output}->{response}->{command}."\n";
	print OUT "; Server file : ".$answer->{output}->{response}->{server}."\n";
	print OUT $answer->{output}->{response}->{client}."\n";
	# 	if ($answer->{output}->{response}->{client} =~ 'tgccaa'){
	# 	    print OUT "Passed\n";
	# 	    exit 0;
	# 	} else {
	# 	    print OUT "Unexpected data\n";
	# 	    exit 2;
	# 	}
      } else {
	print OUT "No answer\n";
	exit 1;
      }
    };

  if ($@) {
    warn "Caught an exception\n";
    warn $@."\n";
    exit 1;
  }
}
