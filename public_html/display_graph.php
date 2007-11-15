<html>
<head>
   <title>GrA-tools - display-graph</title>
   <link rel="stylesheet" type="text/css" href = "main_grat.css" media="screen">
</head>
<body class="results">
<?php 
  require ('functions.php');
  title('display-graph - results');
  # Error status
  $error = 0;
  # Get parameters
  $in_format = $_REQUEST['in_format'];
  $out_format = $_REQUEST['out_format'];
  if ($_FILES['graph_file']['name'] != "") {
    $graph_file = uploadFile('graph_file');
  } else if ($_REQUEST['pipe_graph_file'] != "")  {
    $graph_file = $_REQUEST['pipe_graph_file'];
  }
  $now = date("Ymd_His");
  $graph = $_REQUEST['graph'];
  $layout = $_REQUEST['layout'];
  if ($layout == 'on') {
    $layout = 1;
  }
  $s_col = $_REQUEST['s_col'];
  $t_col = $_REQUEST['t_col'];
  $w_col = $_REQUEST['w_col'];
  $ec_col = $_REQUEST['ec_col'];
  $sc_col = $_REQUEST['sc_col'];
  $tc_col = $_REQUEST['tc_col'];
  
  ## If a file and a graph are submitted -> error
  if ($graph != "" && $graph_file != "") {
    $error = 1;
    error("You must not submit both a graph and a graph file");
  }

  ## No specification of the source and target columns
  if ($in_format == "tab" && $s_col == "" && $t_col == "") {
    warning("Default value for source and target columns for tab-delimited input format are 1 and 2");
  }
  ## put the content of the file $graph_file in $graph
  if ($graph_file != "" && $graph == "") {
    $graph = storeFile($graph_file);
  }
  ## If no graph are submitted -> error
  if ($graph == "" && $graph_file == "") {
    $error = 1;
    error("You must submit an input graph");
  }
  ## If display is not selected and the format is not GML -> error
  if ($in_format != "gml" && $layout != "1") {
    $error = 1;
    error("You must calculate the layout for graphs in format $in_format");
  }
  
  if (!$error) { 
  
    $graph = trim_text($graph);
    ## Load the parameters of the program in to an array
    $parameters = array( 
      "request" => array(
      "informat"=>$in_format,
        "outformat"=>$out_format,
        "inputgraph"=>$graph,
        "scol"=>$s_col,
        "tcol"=>$t_col,
        "layout"=>$layout,
        "tccol"=>$tc_col,
        "sccol"=>$sc_col,
        "eccol"=>$ec_col
      )
    );
    # Info message
    info("Results will appear below");
    echo"<hr>\n";
  
    # Open the SOAP client
    $client = new SoapClient(
                       'http://rsat.scmbb.ulb.ac.be/rsat/web_services/RSATWStest.wsdl',
                           array(
                                 'trace' => 1,
                                 'soap_version' => SOAP_1_1,
                                 'style' => SOAP_DOCUMENT,
                                 'encoding' => SOAP_LITERAL
                                 )
                           );
    # Execute the command
    $echoed = $client->display_graph($parameters);

    $response =  $echoed->response;
    $command = $response->command;
    $server = $response->server;
    $client = $response->client;
    $temp_file = explode('/',$server);
    $temp_file = end($temp_file);
    $resultURL = $WWW_RSA."/tmp/".$temp_file;


    # Display the results
    echo "The results is available at the following URL ";
    echo "<a href = '$resultURL'>$resultURL</a>";
 }

?>
