<?php
  // NeAT TITLE
  Function title($title) {
    echo "<H3><a href='NeAT_home.html'>NeA-tools</a> - $title</H3>\n";
  } 
?>

<?php
  // NeAT ERROR
  Function error($error) {
    echo "<H4>Error : </H4><blockquote class='error'>$error</blockquote></h4><br>";
  } 
?>

<?php
  // NeAT WARNING
  Function warning($warning) {
    echo "<H4>Warning : </H4><blockquote class ='warning'>$warning</blockquote><br>";
  } 
?>


<?php
  // NeAT WARNING
  Function demo($demo) {
    echo "<H4>Comment on the demonstration example : </H4><blockquote class ='demo'>$demo</blockquote><br>";
  } 
?>

<?php
  // NeAT INFO
  Function info($info) {
    echo "<H4>Info : </H4><blockquote class = 'info'>$info </blockquote><br>";
  } 
?>

<?php
  // NeAT INFO
  // This function add an hypertext link
  Function info_link($info, $link_url) {
    echo "<H4>Info : </H4><blockquote class = 'info'><a href = '$link_url'>$info </a></blockquote></a><br>";
  } 
?>


<?php
    Function uploadFile($file) {
    $repertoireDestination = "tmp/";
    $nomDestination = $_FILES[$file]["name"];
    $now = date("Ymd_His");
    $nomDestination = $nomDestination.$now;
    
    if (is_uploaded_file($_FILES[$file]['tmp_name'])) {
        if (rename($_FILES[$file]['tmp_name'], $repertoireDestination.$nomDestination)) {
//             echo "File ".$_FILES[$file]['tmp_name']." was moved to  $repertoireDestination/$nomDestination <br>";
        } else {
            echo "Could not move $_FILES[$file]['tmp_name']"." check that $repertoireDestination exists<br>";
        }          
    } else {
       echo "File ".$_FILES[$file]['tmp_name']." could not be uploaded<br>";
    }
    return $repertoireDestination.$nomDestination;
  }
?>

<?php
    Function storeFile($file) {
      $fh = fopen($file, 'r');
      $theData = fread($fh, filesize($file));
      fclose($fh);
      return $theData;
  }
?>

<?php
/**
 * Strip special invisible characters
 */
Function trim_text($text) {
   $trimmed_text = "";
   $lines = explode("\n",$text);
   $array_count = count($lines);
   for($y=0; $y<$array_count; $y++) {
     $trimmed_text .= trim($lines[$y])."\n";
   }
   return $trimmed_text;
}
?>

<?php
/**
 * Read a property file $props and return a hash
 */
Function load_props($props) {
  $prop_array = array();
  $properties = storeFile($props);
  $lines = explode("\n",$properties);
  $array_count = count($lines);
  for($y=0; $y<$array_count; $y++) {
   $line = trim($lines[$y]);
   if (!preg_match("/^\#/", $line)) {
     $property = explode('=', $line);
     $prop_array[$property[0]] = $property[1];
   }
  }
  return $prop_array;
}
?>


<?php
  # SET OF OPERATION DONE WHEN LOADING EACH PHP PAGE
  $rsat_main = getcwd()."/..";
  $rsat_logs = $rsat_main."/public_html/logs";
  
  # LOAD PROPERTIES
  $properties = load_props($rsat_main."/RSAT_config.props");
  $tmp = $properties[rsa_tmp];
  $WWW_RSA = $properties[www_rsa];
  $log_name = $properties[rsat_site];
  $neat_wsdl = $properties[neat_ws];
  # LOG
  $year = date("Y");
  $month = date("m");
  $neat_log_file = sprintf ("$rsat_logs/log-file_$log_name"."_neat_%04d_%02d", $year,$month);
  $rsat_log_file = sprintf ("$rsat_logs/log-file_$log_name"."_%04d_%02d", $year,$month);  
?>

<?php
## This function returns the name of the script executing it
Function getCurrentScriptName() {
  $currentFile = $_SERVER["SCRIPT_NAME"];
  $parts = Explode('/', $currentFile);
  $currentFile = $parts[count($parts) - 1];
  return $currentFile;
}
?>
<?php
## This function replaces all spaces of a string by tabulation
## If the line starts with a ';' or a '#' it is skipped.
Function space_to_tab($string) {
  $result = "";
  $lines = explode("\n",$string);
  $array_count = count($lines);
  for($i=0; $i<$array_count; $i++) {
    $line = $lines[$i];
    if (!preg_match("/^\#/", $line) && !preg_match("/^\;/", $line)) {
      $line_sp = str_replace(" ", "\t", $line);
      $result .= $line_sp."\n";
    } else {
      $result .= $line."\n";
    }
  }
  return $result;
}

?>
 
<?php
# This function converts a file name from its complete path 
# its URL on the RSAT webserver
# For example : /home/rsat/rsa-tool/public_html/tmp/brol.truc
# will be converted to
# http://rsat.scmbb.ulb.ac.be/rsat/tmp/brol.truc
Function rsat_path_to_url ($file_name) {
    global $WWW_RSA;
    $temp_file = explode('/',$file_name);
    $temp_file = end($temp_file);
    $resultURL = $WWW_RSA."/tmp/".$temp_file;
    return $resultURL;
}

?>
 
 
<?php
## This function returns the name of the script executing it
Function AlphaDate() {
  $my_date = exec("date +%Y_%m_%d.%H%M%S", $my_date);
  trim($my_date);
  return $my_date;
}
?> 
<?php
## This function returns the name of the script executing it
Function check_integer($string) {
  return (preg_match("/[0-9]*/", $string));
}
?> 
<?php 
################################################################
### store info into a log file in a conveninent way for 
### subsequent login statistics
### Usage:
###     UpdateLogFile();
###     UpdateLogFile($script_name);
###     UpdateLogFile($script_name, $message);
### If script name is empty or null... the program determine
### the name of the file

Function UpdateLogFile($suite ,$script_name, $message) {
//   echo "<pre>";
  if ($script_name == "") {
    $script_name = getCurrentScriptName();
  }
  # LOAD GLOBAL VARIABLES
  global $log_file, $log_name, $rsat_log_file, $neat_log_file;
  if ($suite == "rsat") {
    $log_file = $rsat_log_file;
  } else {
    $log_file = $neat_log_file;
  }
  # LOAD OTHER VARIABLES
  $my_date = AlphaDate();
  $user = getenv('REMOTE_USER');
  $address = getenv('REMOTE_ADDR');
  $host = getenv('REMOTE_HOST');
  $e_mail = "";
  $user_address_at_host = $user."@".$address." (".$host.")";
  $to_write = $my_date."\t".$log_name."\t".$user_address_at_host."\t".$script_name."\t".$e_mail."\t".$message."\n";
  # Write to the file
  $log_handle = fopen($log_file, 'a');
  
  fwrite($log_handle, $to_write);
  fclose($log_handle);
  chmod ($log_file, 0777);
}

