#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use SOAP::Lite 
    on_action => sub {
       sprintf '%s/%s', @_
    },
    on_fault => sub { 
	my($soap, $res) = @_; 
#      die ref $res ? $res->faultstring : $soap->transport->status, "\n";
	print "ERROR: ". $soap->transport->status . "\n"
    }
#     ,'trace'
    ;
my %options=();
getopts("hu:o:i:",\%options);
# like the shell getopt, "d:" means d takes an argument
die "Unprocessed by Getopt::Std:\n" if $ARGV[0];

if ($options{h}) {
  print "pathway-extractor_soapclient OPTIONS\n";
  print "===================\n";
  print "-h displays this help message and exit\n";                                                                                                                             
  print "-u server url \n";
  print "-o output directory \n";
#   print "-i seeds file \n";

  exit(0);
}
my $url = $options{u} || "http://localhost";

my $outputdir = $options{o} || "." ;


my $soap = SOAP::Lite
    -> uri("$url/PathwayExtractor_WS")
    -> proxy("$url/rsat/web_services/RSATWM.cgi",timeout=>1000);

 
    my $results=  $soap->infer_pathway("NP_416523.1\tNP_416524.1\tNP_416525.1\tNP_416526.4\tNP_416527.1\tNP_416528.2\tNP_416529.1\tNP_416530.1\tPHOSPHORIBOSYL-ATP","Escherichia_coli_strain_K12-83333-Uniprot","KEGG_v550_RPAIR_notdirected"); 
#     my $results=  $soap->returnhash();
    
    
  eval {  
    my %resulthash = %{$results->result};
    
    print "Output URL: " . $resulthash{"url"}."\n";
    print "Output filename: $outputdir/".$resulthash{"filename"}."\n" ;
    if($resulthash{"file"}){
      open (ZIPFILE, '>'.$outputdir."/".$resulthash{"filename"});
      print ZIPFILE $resulthash{"file"};
      close (ZIPFILE);
    }else {
      die "no file content returned";
    }
    
}