package RSAT::server;

require RSAT::util;
require RSAT::message;

unless ($ENV{RSAT}) {
    $ENV{RSAT} = $0; #
#    $ENV{RSAT} =~ s|\/[^\/]+$||g; ## Guess RSAT path from module full name
    $ENV{RSAT} =~ s|/+perl-scripts.*||; ## Guess RSAT path from module full name
    $ENV{RSAT} =~ s|/+public_html.*||; ## Guess RSAT path from module full name
}

################################################################
## Return the path of a program.
##
## The function successively checks if the program exists in various
## directories: 
## 1)  $ENV{RSAT_BIN} (defined in RSAT_config.props)
## 2)  $ENV{RSAT}/bin
## 3) in the user path
##
## Usage:
##    my $program_path = &RSAT::server::GetProgramPath("program_name", $die_on_error, @preferred_paths);
sub GetProgramPath {
    my ($program_name, $die_on_error, @preferred_paths) = @_;
    my $program_path = "";

    ## Find the preferred location of the program
    my @rsat_path = @preferred_paths;
    if (defined($ENV{RSAT_BIN})) {
      push @rsat_path, ($ENV{RSAT_BIN});
    };
    push @rsat_path, ($ENV{RSAT}."/bin/",
		      $ENV{RSAT}."/python-scripts/",
		      $ENV{RSAT}."/perl-scripts/",
		      ".");

    my $path_found = 0;
    foreach my $dir (@rsat_path) {
      my $possible_path = $dir."/".$program_name;
      $possible_path =~ s|/+|/|g;
#      &RSAT::message::Debug("GetProgramPath()", "testing", $program_name, $possible_path) if ($main::verbose >= 10);
      if (-e $possible_path) {
	## If the RSAT property file contains a RSAT_BIN, use it as
	## preferred path
	$program_path = $possible_path;
	last;
      }
    }

    ## If the path has ont ben found yet, find the program anywhere in
    ## the user path
    unless ($program_path) {
	$program_path = `which $program_name`;
	chomp($program_path);
    }


#     if (($ENV{RSAT_BIN}) && (-e $ENV{RSAT_BIN}."/".$program_name)) {
# 	## If the RSAT property file contains a RSAT_BIN, use it as
# 	## preferred path
# 	$program_path = $ENV{RSAT_BIN}."/".$program_name;
#     } elsif (-e $ENV{RSAT}."/bin/".$program_name) {
# 	## Standard RSAT bin directory
# 	$program_path = $ENV{RSAT}."/bin/".$program_name;
#     } else {
# 	## Find the program anywhere in the user path
# 	$program_path = `which $program_name`;
# 	chomp($program_path);
#     }

    ## Check if the program path has been found
    unless ($program_path) {
      if ($die_on_error) {
	&RSAT::error::FatalError("The program ".$program_name." is not found in your path.");
      } else {
	&RSAT::message::Warning("The program ".$program_name." is not found in your path.");
      }
    }

    unless (-x $program_path) {
      if ($die_on_error) {
	&RSAT::error::FatalError("The program ".$program_path." cannot be run. ");
      } else {
	&RSAT::message::Warning("The program ".$program_path." cannot be run. ");
      }
    }

    &RSAT::message::Info("&RSAT::server::GetProgramPath()", "path found", $program_path)
	if ($main::verbose >= 4);
    return $program_path;
}

################################################################
#### increment the counter file for monitoring web access
sub UpdateCounterFile {
    my $nb_visitors = 1;

    ### read previous counter value
    if (-e $counter_file) {
	open(COUNTER, "<$counter_file");
	#flock(COUNTER, 2);
	$nb_visitors = <COUNTER>;
	#flock(COUNTER,8);
	close(COUNTER);
	$nb_visitors++;
    }

    ### save new counter value
    open(COUNTER, ">$counter_file");
    #flock(COUNTER,2);
    print COUNTER $nb_visitors;
    #flock(COUNTER,8);
    close(COUNTER);
    return $nb_visitors;
}


=pod

=item B<DetectDeniedIP()>

Check that the client IP address is not blacklisted on this RSAT
server. If denied, die with error message.

=cut

sub DetectDeniedIP {

    ## IP address of the client computer
    my $client_ip = $ENV{'REMOTE_ADDR'};
    &RSAT::message::Info("Your IP address: ".$client_ip) if ($main::verbose >= 5);

    ## File with the list of denied addresses
    my $rsat_site = $ENV{rsat_site};
    my ($sec, $min, $hour,$day,$month,$year) = localtime(time());
    $year += 1900;
    my $denied_ip_file= $ENV{RSAT}."/denied_IP_addresses_".$rsat_site."_".$year.".tab";
    &RSAT::message::Info("Denied IP file", &RSAT::util::hide_RSAT_path($denied_ip_file)) if ($main::verbose >= 5);

    my ($in) = &RSAT::util::OpenInputFile($denied_ip_file);
    while (<$in>) {
	chomp();
	my ($ip, $nb, $reason) = split(/\t/, $_);
	&RSAT::message::Debug("Denied", $ip) if ($main::verbose >= 10);
	if ($client_ip eq $ip) {
	    die "Access denied to IP address $client_ip\t$reason\n";e
	}
    }
    return (0);
}



################################################################
### store info into a log file in a conveninent way for 
### subsequent login statistics
### Usage:
###     &UpdateLogFile($script_name, $message, $log_file, $user_email);
sub UpdateLogFile {
  my ($script_name, $message, $log_file, $user_email) = @_;

  ## Check script name
  unless ($script_name) {
    $script_name = &RSAT::util::ShortFileName($0);
  }

  ## Check log file
  unless ($log_file) {
    $log_file = $main::log_file;
  }

  &RSAT::message::Debug("&RSAT::server::UpdateLogFile()",
			"<p>script=".$script_name,
			"<p>message=".$message,
			"<p>log=".$log_file,
			"<p>email=".$user_email,
			 ) if ($main::verbose >= 5);

  if (open LOG, ">>".$log_file) {
    #flock(LOG,2);
    $date = &RSAT::util::AlphaDate();
    $date =~ s/\n//;
    print LOG join ("\t",
		    $date,
		    $ENV{rsat_site},
#		    "$ENV{'REMOTE_USER'}\@$ENV{'REMOTE_ADDR'} ($ENV{'REMOTE_HOST'})",
		    $ENV{'REMOTE_ADDR'},
		    $script_name,
		    $user_email,
		    $message
		    ), "\n";
    #flock(LOG,8);
    close LOG;
  }
  chmod 0777, $log_file;
}


################################################################
## Report a suspicious content in a Web form, considered as potential
## Web attack.
##
### Usage:
###     &ReportWebAttack($script_name, $message, $log_file, $user_email);
sub ReportWebAttack {
  my ($script_name, $attack_type, $attack_detail, $user_email) = @_;

  ## Check script name
  unless ($script_name) {
    $script_name = &RSAT::util::ShortFileName($0);
  }

  ## Check log file
  unless ($log_file) {
    $log_file = $main::web_attacks_log_file;
  }

  &RSAT::message::Debug("&RSAT::server::ReportWebAttack()",
			"<p>script=".$script_name,
			"<p>message=".$message,
			"<p>log=".$log_file,
			"<p>email=".$user_email,
			 ) if ($main::verbose >= 5);

  if (open LOG, ">>".$log_file) {
    #flock(LOG,2);
    $date = &RSAT::util::AlphaDate();
    $date =~ s/\n//;
    print LOG join ("\t",
		    $date,
		    $ENV{rsat_site},
		    "$ENV{'REMOTE_USER'}\@$ENV{'REMOTE_ADDR'} ($ENV{'REMOTE_HOST'})",
		    $script_name,
		    $user_email,
		    $attack_type,
		    $attack_detail,
		    ), "\n";
    #flock(LOG,8);
    close LOG;
  }
  chmod 0777, $log_file;
}


################################################################
## Append the execition time of a the current script in a specific log file
## Usage:
##     &UpdateExecTimeLogFile($start_time, $done_time, $elapsed);
sub UpdateExecTimeLogFile {
  my ($start_time, $done_time, $elapsed) = @_;

  my $script_name = &RSAT::util::ShortFileName($0) || 'undefined';
  my $command = join (" ", $script_name, @ARGV);

  ## Assign value to uninitialized values
  unless ($start_time) {
    $start_time = "Unspecified";
  }
  unless ($done_time) {
    $done_time = "Unspecified";
  }
  unless ($start_time) {
    $elapsed = "Unspecified";
  }
  my $login = getlogin || getpwuid($<) || "Kilroy";

  &RSAT::message::TimeWarn("Updating execution time log file", $main::exec_time_log_file)
    if ($main::verbose >= 4);

  ## Write header of the exec time log file if required
  &RSAT::message::Debug("exec_time_log_file", $main::exec_time_log_file) if ($main::verbose >= 5);
  unless (-e $main::exec_time_log_file) {
    open LOG, ">".$main::exec_time_log_file;
    print LOG join ("\t",
		    "#start_date.time",
		    "done_date.time  ",
		    "seconds",
		    "PID",
		    "username",
		    "script_name",
		    "command",
		   ), "\n";
    close LOG;
  }

  open LOG, ">>".$main::exec_time_log_file;
  print LOG join ("\t",
		  $start_time,
		  $done_time,
		  $elapsed,
		  $$,
		  $login,
		  $script_name,
		  $command,
		 ), "\n";
  close LOG;
  chmod 0777, $main::exec_time_log_file;
}



################################################################
#### send a unix command to remove a file the next day
#### Usage:
#### &DelayedRemoval($file_to_remove, $delay);
####
sub DelayedRemoval {
    my ($file_to_remove, $delay) = @_;
    $delay = $delay || "24 hours";
    unless (-e $file_to_remove) {
	&RSAT::message::MessageToAdmin("DelayedRemoval: file $file_to_remove does not exist");
	return();
    }
    unless (-r $file_to_remove) {
	&RSAT::message::MessageToAdmin("DelayedRemoval: file $file_to_remove is not readable");
	return();
    }
    unless (-w $file_to_remove) {
	&RSAT::message::MessageToAdmin("DelayedRemoval: file $file_to_remove is not writable");
	return();
    }

    &RSAT::message::MessageToAdmin("DelayedRemoval: file $file_to_remove will be removed in $delay") if ($ENV{rsat_echo} >= 2);

    #### TEMPORARILY INACTIVATED BECAUSE IT MOBILIZES A LOT OF MEMORY
    return();

    open REMOVE, "| at now + $delay";
    print REMOVE "rm -f $file_to_remove \n";
    close REMOVE;
}



################################################################
## The initialization is performed in the main scope, because this si
## the place where most RSAT programs expect to find the global
## variables, due to the initial organization of RSAT.
##
## This should be changed at some point, by having server-specific
## variables attached to the RSAT::server class.

package main;

################################################################
## Read props file
sub ReadProperties {
  if ($0 =~ /([^(\/)]+)$/) {

    ## This flag is activated if the site-specific config is not found
    my $default_props = 0;

    ## Identify the property file
    my $property_file = "";
    if (defined($ENV{RSAT})) {
      $property_file = "$ENV{RSAT}/RSAT_config.props";
    } else {
      $property_file = $`."../RSAT_config.props"; #`
    }

    ## Check that site-specific property file has been created (nd
    ## hopefully configured). If not, issue warning and try to
    ## improvise with the default config file distributed with RSAT
    ## (no guarantee).
    unless (-e $property_file) {
      &RSAT::message::Warning("This RSAT site is not properly configured.\n",
			      '$ENV{RSAT}='.$ENV{RSAT},
			      "\n\tPoperty file does not exist: ".$property_file,
			      "\n\tPlease contact the system administrator.");
      $property_file = $`."../RSAT_config_default.props"; #`
      $default_props = 1;
    }

    ## Load RSAT site-specific properties
    if (-e $property_file) {
      my ($props) = &RSAT::util::OpenInputFile($property_file);
      while (<$props>) {
	next if (/^#/);
	next if (/^;/);
	next unless (/\S/);
	chomp();
	if (/\=/) {
	  my $value = $'; #'
	  my $key = $`; #`
	  if ($default_props) {
	    $value =~ s|\[RSAT_PARENT_PATH\]/rsa-tools|$ENV{RSAT}|g;
	  }
	  $ENV{$key} = $value;
	  $server::config{$key} = $value;
	  #        &RSAT::message::Info("Site config", sprintf("%-15s\t%s\t%s", $key, $ENV{$key})) if ($main::verbose >= 10);
	}
      }
    }
  }
}


################################################################
## Read Perl config files.
##
##  WARNING: This was the old way to treat the configuration. The config is
## now read from the propery file RSAT_config.props. This piece of code should
## be supopressed but I firts have to check that everything works fine.
sub ReadConfig {
  if ($0 =~ /([^(\/)]+)$/) {
    my $config_file;
    if (-e $`."../RSA.config") {
      $config_file = $`."../RSA.config";
    } elsif (-e $`."../../RSA.config") {
      $config_file = $`."../../RSA.config";
    }
    &RSAT::message::Info("RSAT config file", $config_file) if ($main::verbose >= 4);
    if ($config_file) {
      require $config_file;
    } else {
      return();
      &RSAT::error::FatalError("Cannot find the old-format config file", "RSA.config", "from dir", $`);
    }

    ## Read user-defined local configuration if defined
    if ($ENV{'RSA_LOCAL_CONFIG'}) {
      if (-e $ENV{'RSA_LOCAL_CONFIG'}) {
	&RSAT::message::Info("Reading local configuration file", $ENV{'RSA_LOCAL_CONFIG'}) if ($main::verbose >= 1);
	if (-r $ENV{'RSA_LOCAL_CONFIG'}) {
	  require $ENV{'RSA_LOCAL_CONFIG'};
	} else {
	  warn (";WARNING: cannot read local config file ",
		$ENV{'RSA_LOCAL_CONFIG'},
		"\n"),
	      }
      } else {
	warn (";WARNING: local config file ",
	      $ENV{'RSA_LOCAL_CONFIG'},
	      " does not exist\n"),
	    }
    }
  } else {
    &RSAT::error::FatalError("Error: problem when opening config file. Please contact jvanheld\@bigre.ulb.ac.be");
  }
}


################################################################
## Load additional genomes, locally installed in user's account
sub LoadLocalOrganisms {
  ## TO BE IMPLEMENTED
  ## - load the organisms from a tab-delimited file
  ## - check that the organisms ar esuppored by get-orthologs

  if ($ENV{'RSAT_LOCAL_ORGANISMS'}) {
    if (-e $ENV{'RSAT_LOCAL_ORGANISMS'}) {
      if (-r $ENV{'RSAT_LOCAL_ORGANISMS'}) {
	&RSAT::message::Warning("LOADING OF LOCAL ORGANISMS STILL HAS TO BE IMPLEMENTED. IGNORED.");
      } else {
	&RSAT::message::Warning(";WARNING: cannot read local config file ", $ENV{'RSAT_LOCAL_ORGANISMS'})
      }
    } else {
      &RSAT::message::Warning(";WARNING: local config file does not exist ", $ENV{'RSAT_LOCAL_ORGANISMS'})
    }
  }
}

################################################################
## Initialize the global variables required for RSAT
## MANY OF THESE VARIABLES ARE OBSOLETE
## THIS SHOULD BE CLEANED WHEN I FIND TIME TO DO IT
sub InitRSAT {
  umask 0022;

  &ReadProperties();
#  &ReadConfig();
  &LoadLocalOrganisms();



  ## Directories
  $main::BIN = "$ENV{RSAT}/bin";
  $main::LIB = "$ENV{RSAT}/lib";

  ## Check temporary directory
  $main::TMP = $ENV{RSAT}."/public_html/tmp";


  ################################################################
  ## I would like to define a month-specific tmp directory But this
  ## requires to revisit all the pulic-html + perl-script dir to
  ## replace $RSAT/public_html/tmp by this $TMP.
#   my ($sec, $min, $hour,$day,$month,$year) = localtime(time());
#   $year_month = sprintf("%02d_%02d", $day, $month+1, 1900+$year);
#   $main::TMP .= "/".$year_month;
   &RSAT::util::CheckOutDir($main::TMP);
   chmod(0777, $main::TMP);
#   &RSAT::message::Debug("Temporary dir", $main::TMP) if ($main::verbose >= 5);

  $main::SCRIPTS = "$ENV{RSAT}/perl-scripts";
  $main::PYTHON = "$ENV{RSAT}/python-scripts";

  ################################################################
  ## Redirect queries to a remote server
  ##
  ## This piece of code used to ensure load balancing between several
  ## machines, but it relies on rsh, which is not a safe protocol. In
  ## case of need, it could be adapted to work with ssh in the
  ## future. Anyway, this will probably be replaced by more efficient
  ## protocols for grid computation.
  if ($main::REMOTE_SERVER) {
    my $login = getlogin();
    if (($login eq "webserv") || !($login)) {
      $main::NICE = "nice +5";
      $main::RSH = "rsh -l jvanheld ${REMOTE_SERVER} $NICE";
      $main::SCRIPTS = "$RSH rsa-tools/perl-scripts";
      $main::BIN = "$RSH rsa-tools/bin";
    }
  }
  $main::HTML = "$ENV{RSAT}/public_html"; 
  $main::WWW_TMP = "$ENV{rsat_www}/tmp";
  #$ENV{SERVER_ADMIN} = "jvanheld\@bigre.ulb.ac.be";
  $main::LOGS = "$ENV{RSAT}/logs";
  $main::counter_file = "$LOGS/count-file";
  my ($sec, $min, $hour,$day,$month,$year) = localtime(time);
  $main::log_file = join("", $LOGS, "/log-file_", $ENV{rsat_site}, sprintf("_%04d_%02d", $year+1900,$month+1));
  $main::web_attacks_log_file = join("", $LOGS, "/web_attacks_log_", $ENV{rsat_site}, sprintf("_%04d_%02d", $year+1900,$month+1), ".txt");
  $main::exec_time_log_file = join("", $LOGS, "/exec_time_log_", $ENV{rsat_site}, sprintf("_%04d_%02d", $year+1900,$month+1), ".txt");
  $main::start_time_log_file = join("", $LOGS, "/start_time_log_", $ENV{rsat_site}, sprintf("_%04d_%02d", $year+1900,$month+1), ".txt");
  $main::date = &RSAT::util::AlphaDate();
}

return(1);
