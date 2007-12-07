<html>
<head>
   <title>Network Analysis Tools - convert-graph</title>
   <link rel="stylesheet" type="text/css" href = "main_grat.css" media="screen">
</head>
<body class="results">
<?php 
  require ('functions.php');
  # log file update
  UpdateLogFile("neat","","");
  title('compare-graphs - results');
  # Error status
  $error = 0;
  # Get parameters
  $in_formatQ = $_REQUEST['in_formatQ'];
  $in_formatR = $_REQUEST['in_formatR'];
  
  
  $out_format = $_REQUEST['out_format'];
  if ($_FILES['graph_fileQ']['name'] != "") {
    $graph_fileQ = uploadFile('graph_fileQ');
  } else if ($_REQUEST['pipe_query_graph_file'] != "") {
    $graph_fileQ = $_REQUEST['pipe_query_graph_file'];
  }
  if ($_FILES['graph_fileR']['name'] != "") {
    $graph_fileR = uploadFile('graph_fileR');
  }
  $now = date("Ymd_His");
  $graphQ = $_REQUEST['graphQ'];
  $graphR = $_REQUEST['graphR'];
  $directed = $_REQUEST['directed'];
  $s_colQ = $_REQUEST['s_colQ'];
  $t_colQ = $_REQUEST['t_colQ'];
  $w_colQ = $_REQUEST['w_colQ'];
  $s_colR = $_REQUEST['s_colR'];
  $t_colR = $_REQUEST['t_colR'];
  $w_colR = $_REQUEST['w_colR'];
  if ($directed == "on") {
    $directed = 1;
  }
  $self = $_REQUEST['self'];  
  if ($self == "on") {
    $self = 1;
  }
  $return =  $_REQUEST['return'];
  $outweight =  $_REQUEST['outweight']; 
  ## If a query graph file and a query graph are submitted -> error
  if ($graphQ != "" && $graph_fileQ!= "") {
    $error = 1;
    error("You must not submit both a query graph and a query graph file");
  }
  ## If a query graph file and a query graph are submitted -> error
  if ($graphR != "" && $graph_fileR!= "") {
    $error = 1;
    error("You must not submit both a reference graph and a reference graph file");
  }
  ## No specification of the source and target columns
  if ($in_format_Q == "tab" && $s_colQ == "" && $t_colQ == "") {
    warning("Default value for source and target columns for query graph in tab-delimited input format are 1 and 2");
  }
  ## No specification of the source and target columns
  if ($in_format_R == "tab" && $s_colR == "" && $t_colR == "") {
    warning("Default value for source and target columns for reference graph in tab-delimited input format are 1 and 2");
  }
  ## put the content of the file $graph_file in $graph
  if ($graph_fileQ != "" && $graphQ == "") {
    $graphQ = storeFile($graph_fileQ);
  } 
  ## put the content of the file $graph_file in $graph
  if ($graph_fileR != "" && $graphR == "") {
    $graphR = storeFile($graph_fileR);
  }
  ## If no graph are submitted -> error
  if ($graphQ == "" && $graph_fileQ == "") {
    $error = 1;
    error("You must submit a query input graph");
  }
  ## If no graph are submitted -> error
  if ($graphR == "" && $graph_fileR == "") {
    $error = 1;
    error("You must submit a reference input graph");
  }
  
   if (!$error) { 
     $graphQ = trim_text($graphQ);
     $graphR = trim_text($graphR);
     $parameters = array( 
       "request" => array (
         "Qinformat"=>$in_formatQ,
         "Rinformat"=>$in_formatR,
         "outformat"=>$out_format,
         "outweight"=>$outweight,
         "Rinputgraph"=>$graphR,
         "Qinputgraph"=>$graphQ,
         "Qwcol"=>$w_colQ,
         "Qscol"=>$s_colQ,
         "Qtcol"=>$t_colQ,
         "Rwcol"=>$w_colR,
         "Rscol"=>$s_colR,
         "Rtcol"=>$t_colR,
         "directed"=>$directed,
         "return"=>$return,
         "self"=>$self
       )
     );
         
    # Info message
    info("Results will appear below");
    echo"<hr>\n";
  
    # Open the SOAP client
    $client = new SoapClient(
                       "$WWW_RSA"."/web_services/RSATWS.wsdl",
                           array(
                                 'trace' => 1,
                                 'soap_version' => SOAP_1_1,
                                 'style' => SOAP_DOCUMENT,
                                 'encoding' => SOAP_LITERAL
                                 )
                           );
    # Execute the command
    echo "<pre>";
    $echoed = $client->compare_graphs($parameters);
    echo "</pre>"; 
    $response =  $echoed->response;
    $command = $response->command;
    $server = $response->server;
    $client = $response->client;
    $server = rtrim ($server);
    $temp_file = explode('/',$server);
    $temp_file = end($temp_file);
    $resultURL = $WWW_RSA."/tmp/".$temp_file;
    # The comment file has the same name as the
    # result file with ".comments" at the end of the string.
    $comments_temp_file = $server.".comments";
    $comments = storeFile($comments_temp_file);
    # Comments
    echo "<pre>";
    echo "$comments";
    echo "</pre><hr>";
    # Display the results
    echo "The results is available at the following URL ";
    echo "<a href = '$resultURL'>$resultURL</a>"; 
    echo "<hr>\n";
  echo "
  <TABLE CLASS = 'nextstep'>
    <TR>
      <Th colspan = 3>
        Next step
      </Th>
    </TR>
    <TR>
      <TD>
        <FORM METHOD='POST' ACTION='display_graph_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Display the graph'>
        </form>
      </td>
      <TD>
        <FORM METHOD='POST' ACTION='convert_graph_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Convert $out_format to another format'>
        </form>
      </td>
      <TD>
        <FORM METHOD='POST' ACTION='random_graph_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Randomize this graph'>
        </form>
      </td>
    </tr>
    <tr>
      <TD>
        <FORM METHOD='POST' ACTION='graph_get_clusters_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Map clusters or extract a subnetwork'>
        </form>
      </td>
      <TD>
        <FORM METHOD='POST' ACTION='graph_node_degree_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Nodes degrees computation'>
        </form>
      </td>
      <TD>
        <FORM METHOD='POST' ACTION='graph_neighbours_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Neighbourhood analysis'>
        </form>
      </td>    
    </tr>
    <TR>
      <TD>
        <FORM METHOD='POST' ACTION='mcl_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$server'>
          <input type='hidden' NAME='graph_format' VALUE='$out_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='MCL Graph clustering'>
        </form>
      </td>
      </tr>
  </table>";
  }
?>