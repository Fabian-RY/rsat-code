#!/usr/bin/perl -w

################################################################
## This script permits to interactively define the environment
## variables and parameters that will be used by the RSAT progams.
## 
## These parameters are stored in different files for different
## purposes:
##
## RSAT_config.props
##    config file read by RSAT programs in various languages: Perl,
##    python, java
##
## RSAT_config.mk
##    environment variables for the makefiles
##
## RSAT_config.bashrc
##    environment variables that should be loaded in the (bash) shell
##    of RSAT users. There is currently no support for csh or tcsh,
##    but the file can easily be convered to obtain a non-bash cshrc
##    file.
##
## RSAT_config.conf
##    RSAT configuration for the Apache web server.

our %prev_param = ();
our %new_param = ();


################################################################
## List of file extensions for config files. 
our @props_extensions = ("props", "mk", "bashrc", "conf");

## Indicate, for each extension of config file, whether the user
## should be prompted for variable values.
our %auto_extension = ();
$auto_extension{props} =0;
$auto_extension{mk} =0;
$auto_extension{bashrc} =1;
$auto_extension{conf} =1;

## Print the help message
if (scalar(@ARGV) > 0) {
  &PrintHelp();
}

package main;
{

  ## BEWARE: this script MUST be executed from the rsat directory,
  ## because the RSAT path is guessed from the current directory.
  unless ($rsat_path) {
    my $pwd = `pwd`;
    chomp($pwd);
    if ($pwd =~ /rsat\/*$/) {
      $rsat_path = $pwd;
    }
  }

  ## Prompt for the RSAT path
  print "\nAbsolute path to the RSAT package ? [", $rsat_path, "] ";
  chomp(my $answer = <>);
  if ($answer) {
    $rsat_path = $answer;
  }

  ## Compute RSAT parent path
  $rsat_parent_path = `dirname $rsat_path`;
  chomp($rsat_parent_path);
  warn "RSAT parent path\t", $rsat_parent_path, "\n";

  ## Check that the RSAT path seems correct
  unless ($rsat_path =~ /rsat\/*/) {
    warn ("\nWarning: $rsat_path does not seem to be a conventional RSAT path (should terminate by rsat).", "\n\n");
  }

  ## Check that the RSAT path exists and is a directory
  unless (-d $rsat_path) {
    die ("\nError: invalid RSAT path\n\t", $rsat_path, "\nDoes not correspond to an existing directory on this computer", "\n\n");
  }

  ## Treat successively the two configuration files: .props (for Perl
  ## and php scripts) and .mk (for make scripts).
  warn("\n", "We will now edit configuration files in interactive mode, for the ", 
       scalar(@props_extensions), " following extensions: ", join(", ", @props_extensions), "\n");

  for my $extension (@props_extensions) {

    ## Check that the config file exists in the RSAT path
    my $config_file = $rsat_path."/RSAT_config.${extension}";
    warn("\n\n\n", "################################################################\n", 
	 "## Editing \".${extension}\" configuration file\t", $config_file,"\n\n");

    unless (-f $config_file) {
      my $default_config_file = $rsat_path."/RSAT_config_default.${extension}";
      if (-e $default_config_file) {
	warn ("\nThe config file RSAT_config.${extension} is not found in the RSAT path\n\t", $rsat_path,
	      "\nCopying from default config file\t", $default_config_file,
	      "\n\n");
	system("cp ".$default_config_file." ".$config_file);
      } else {
	die ("\nError: the config file RSAT_config.${extension} is not found in the RSAT path\n\t", $rsat_path,
	     "\nPlease check that the RSAT package has been properly installed in this directory.",
	     "\n\n");
      }
    }

    ## Prompt for the new value
    warn "\nPLEASE CHECK THE FOLLOWING LINE BEFORE GOING FURTHER\n";
    print "\nReady to update config file\t", $config_file, " [y/n] (y): ";
    chomp($answer = <>);
    $answer = "y" unless ($answer);
    unless ($answer eq "y") {
      warn("\nWARNING: Since you did not answer 'y', the edition of config file ${config_file} is aborted.\n");
      die ("Good bye\n\n");
    }

    open CONFIG, $config_file || die "\n\nCannot read config file\t", $config_file, "\n\n";

    ## Create a copy of the config file
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $config_file_bk = $config_file.".bk.".($year+1900)."-".($mon+1)."-".$mday."_".$hour."-".$min."-".$sec;
    warn ("\n\nBackup of previous config file\t", $config_file_bk, "\n\n");
    system("cp ".$config_file." ".$config_file_bk);

    ## Open a new file for writing the new config
    my $new_config_file = $config_file.".updated";
    open NEW_CONF, ">".$new_config_file || die "\n\nCannot write new config file\t", $new_config_file, "\n\n";

    ## Load the RSAT config file
    while (<CONFIG>) {

      ## Treat the Apache config file
      if ($extension eq "conf") {
	## For apache, the only change is to replace[RSAT_PARENT_PATH]
	## by the actual path
	s/\[RSAT_PARENT_PATH\]/${rsat_parent_path}/;
	print NEW_CONF;

      } else {

	if ((/(\S+)=(.*)/) && !(/^#/)) {
	  my $key = $1;
	  my $value = $2;

	  ## Replace the RSAT parent path if required (at first installation)
	  $value =~ s/\[RSAT_PARENT_PATH\]/${rsat_parent_path}/;

#	if ($key eq "rsat_www") {
#	    $param{rsat_www_ori} = $value;
#	    warn "rsat_www_ori\t", $param{rsat_www_ori}, "\n";
#	}

	  ## Replace the RSAT web server path if required (at first installation)
	  if ($key eq "rsat_www") {
	    $value .= "/";
	    $value =~ s|//$|/|;
	  } elsif (($prev_param{rsat_www}) && ($new_param{rsat_www})
		   && ($value =~ /$prev_param{rsat_www}/)
		   && ($new_param{rsat_www} ne $prev_param{rsat_www})) {
	    $value =~ s|$prev_param{rsat_www}|$new_param{rsat_www}|;
	  }
	  $prev_param{$key} = $value;

	  ## If a new value has been specified for the props file,
	  ## propose if for mk as well.
	  if ($extension eq "mk") {
	      if (defined($new_param{$key})) {
		  $value = $new_param{$key};
	      }
	  }

	  ## Prompt for the new value
	  unless ($auto_extension{$extension}) {
	      print "\n", $key, " [", $value, "] : ";
	      chomp(my $new_value = <>);
	      if ($new_value) {
		  $value = $new_value;
	      }
	  }

	  ## Export the line in the new config file
	  if ($extension eq "bashrc") {
	    print NEW_CONF "export ", $key, "=", $value, "\n";
	  } else {
	    print NEW_CONF $key, "=", $value, "\n";
	  }
	  $new_param{$key} = $value;

#	warn join ("\t", "key=".$key, "value=".$value, "param=".$new_param{$key}, "previous=".$prev_param{$key}), "\n";

	} else {
	  print;			## Display comments
	  print NEW_CONF;
	}
      }
    }

    close CONFIG;
    close NEW_CONF;

    system ("mv -f ".$new_config_file." ".$config_file);
    warn ("\n\nBackup of previous config file\n\t", $config_file_bk, "\n");
    warn ("Updated config file\n\t", $config_file."\n\n");
  }


  exit(0);
}


sub PrintHelp {
  print <<End_of_help;

This script allows to update the RSAT config file in an interactive
way. It should be used by RSAT amdinistrators when the configuration
has to be changed (example: change of the IP address of the server).

Author: Jacques.van-Helden\@univ-amu.fr

usage: perl update_rsat_config.pl

End_of_help
  exit(0);
}
