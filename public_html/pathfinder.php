<html>
<head>
   <title>NAT Pathfinder</title>
   <link rel="stylesheet" type="text/css" href = "main_grat.css" media="screen">
</head>
<body class="results">
<?php
  require ('functions.php');
  # log file update thanks to Sylvain
  UpdateLogFile("neat","","");

  title('Results Pathfinder');
  # Error status
  $error = 0;
  # default params
  $default_nodeIntegers = 0;
  $default_returnType = "server";
  # server-related params
  $result_location = "/home/rsat/rsa-tools/public_html/tmp/";
  $result_suffix = "_Result.txt";
  $sylvain_input_format = "tab";
  $sylvain_input_graph = "";

  # Get parameters
  $piped_graph = $_REQUEST['pipe_graph_file'];
  $piped_in_format = $_REQUEST['pipe_in_format'];
  $in_format = $_REQUEST['in_format'];
  $out_format = $_REQUEST['out_format'];
  $sources = $_REQUEST['sources'];
  $targets = $_REQUEST['targets'];
  if ($_FILES['batch_file']['name'] != "") {
    $batch_file = uploadFile('batch_file');
  }
  if ($_FILES['graph_file']['name'] != "") {
    $graph_file = uploadFile('graph_file');
  }
  $graph = $_REQUEST['graph'];
  $graph_id = $_REQUEST['graph_id'];
  $directed = $_REQUEST['directed'];
  $weight = $_REQUEST['weight'];
  $nodeIntegers = $default_nodeIntegers;
  $algorithm =  $default_algorithm;
  $rank = $_REQUEST['rank'];
  $outputType =   $_REQUEST['outputType'];
  $store_graph = $_REQUEST['store_graph'];
  $return_type = $default_returnType;
  # Get advanced parameters
  $algorithm = $_REQUEST['algorithm'];
  $maxWeight = $_REQUEST['maxWeight'];
  $maxLength = $_REQUEST['maxLength'];
  $minLength = $_REQUEST['minLength'];
  $exAttrib = $_REQUEST['exAttrib'];
  $metabolic = $_REQUEST['metabolic']; 

  ############ Check input ########################

  if($piped_graph != ""){
		$graph_file = $piped_graph;
		$in_format = $piped_in_format;
  }

   if ($store_graph == 'on') {
    $store_graph = 1;
  } else {
    $store_graph = 0;
  }

  if ($directed == 'on') {
    $directed = 1;
  } else {
    $directed = 0;
  }
  
  if($metabolic == 'on'){
    $metabolic = 1;
  }else{
    $metabolic = 0;
  }

  ## convert format names
  if($out_format == 'GML'){
  	$sylvain_input_format = 'gml';
  }
  if($out_format == 'flat'){
  	$sylvain_input_format = 'tab';
  }

  ## forbidden to set both batchfile and source and target nodes
  if($batch_file != "" && $sources != "" && $targets != ""){
  	$error = 1;
  	error("Set either a path finding batch file or source and target nodes, but not both.");
  }

  ## set batch file
  if($batch_file != ""){
  	$sources =  storeFile($batch_file);
  	$targets = "";
  }

  ## If a file and a graph are submitted -> error
  if ($graph != "" && $graph_file != "") {
    $error = 1;
    error("You must not submit both a graph and a graph file");
  }

  ## If a graph id and a graph file are submitted -> error
  if ($graph_id != "" && $graph_file != "") {
    $error = 1;
    error("You must not submit both a graph id and a graph file");
  }

   ## If a graph id and a graph  are submitted -> error
  if ($graph_id != "" && $graph != "") {
    $error = 1;
    error("You must not submit both a graph id and a graph.");
  }

  ## No specification of the source and target nodes or of a batch file
  if ($source == "" && $targets == "" && $batch_file == "") {
    error("You need to specify source and target nodes or a batch file.");
  }

  ## put the content of the file $graph_file in $graph
  if ($graph_file != "" && $graph == "") {
    $graph = storeFile($graph_file);
  }

  ## put the content of the graph id into graph
  if($graph_id != "" && $graph == ""){
  	$graph = $graph_id;
  }

  ## If no graph are submitted -> error
  if ($graph == "" && $graph_file == "") {
    $error = 1;
    error("You must submit an input graph");
  }
  
  if (!$error) {
    # convert two spaces in a row into a tab delimiter
    if(strcmp($out_format,'flat') == 0){
        $graph = spaces_to_tab($graph,2);
    }
   
   ########## Launch the client ###############

    $parameters = array(
      "request" => array(
     	'source'=>$sources,
     	'target'=>$targets,
     	'graphString'=>$graph,
        'inFormat'=>$in_format,
        'outFormat'=>$out_format,
    	'directed'=>$directed,
    	'metabolic'=>$metabolic,
    	'exclusionAttr'=>$exAttrib,
    	'nodeIntegers'=>$nodeIntegers,
    	'weight'=>$weight,
    	'algorithm'=>$algorithm,
    	'rank'=>$rank,
    	'maxWeight'=>$maxWeight,
    	'maxLength'=>$maxLength,
    	'minLength'=>$minLength,
    	'outputType'=>$outputType,
    	'storeInputGraph'=>$store_graph,
    	'returnType'=>$return_type
      )
    );
    # Info message
    info("Results will appear below");
    echo"<hr>\n";
    # Open the SOAP client
    $client = new SoapClient(
                      'http://rsat.scmbb.ulb.ac.be/be.ac.ulb.bigre.graphtools.server/wsdl/GraphAlgorithms.wsdl',
                           array(
                                 'trace' => 1,
                                 'soap_version' => SOAP_1_1,
                                 'style' => SOAP_DOCUMENT,
                                 'encoding' => SOAP_LITERAL
                                 )
                           );
    # Execute the command
    $functions = $client->__getFunctions();
    $types = $client->__getTypes();
    # info(print_r($parameters));
    # info(print_r($functions));
 	# info(print_r($types));
 	try{
        $echoed = $client->pathfinding($parameters);
    }catch(SoapFault $fault){
       echo("The following error occurred:");
       error($fault);
       $error = 1;
    }

    ########## Process results ###############

    $response =  $echoed->response;
    # result processing
    $command = $response->command;
    $server = $response->server;
    $client = $response->client;
    $graphid = $response->graphid;
    if(ereg('PATHFINDER ERROR',$server)){
    	$error = 1;
    	error("$server");
    }
    if($error == 0){
   		# location of result file on server (absolute path)
    	$file_location = $result_location . $graphid . $result_suffix;

        # content of result file
        $fileContent = storeFile($file_location);
        # Display the results
    	echo "<align='left'>The result is available as text file at the following URL:<br> ";
    	echo "<a href = '$server'>$server</a><br></align>";

    	# Text-to-html web service (for table of paths only)
    	if(strcmp($outputType,'pathsTable') == 0){
    	 $rsat_client = new SoapClient(
                       "$WWW_RSA"."/web_services/RSATWS.wsdl",
                           array(
                                 'trace' => 1,
                                 'soap_version' => SOAP_1_1,
                                 'style' => SOAP_DOCUMENT,
                                 'encoding' => SOAP_LITERAL
                                 )
                           );
        $tth_parameters = array(
          "request" => array(
          "inputfile"=>$fileContent,
          "chunk"=>1000,
         	)
        );

        $tth_echoed = $rsat_client->text_to_html($tth_parameters);
        $tth_response =  $tth_echoed->response;
        $tth_command = $tth_response->command;
        $tth_server = $tth_response->server;
       	$tth_server = rtrim ($tth_server);
        $tth_temp_file = explode('/',$tth_server);
   	    $tth_temp_file = end($tth_temp_file);
    	$tth_resultURL = $WWW_RSA."/tmp/".$tth_temp_file;
    	echo "<align='left'>The result is available as HTML page at the following URL:<br> ";
    	echo "<a href = '$tth_resultURL'>$tth_resultURL</a><br>";
    	echo "You can sort the rows according to a selected column by clicking on the header entry of that column.<br></align>";
    	}
    	# in case of tab-format, truncate nodes to make it readable by Sylvain Brohee's tools
    	if(strcmp($out_format,'flat') == 0){
    		if(ereg(';ARCS',$fileContent)){
    			$sylvain_input_graph = end(explode(';ARCS',$fileContent));
    		}
    	}else{
    		$sylvain_input_graph = $fileContent;
   		 }
    	# remove leading or trailing white spaces or end of lines
    	$sylvain_input_graph = ltrim($sylvain_input_graph,"\n");
    	$sylvain_input_graph = rtrim($sylvain_input_graph,"\n");
    	$sylvain_input_graph = ltrim($sylvain_input_graph);
    	$sylvain_input_graph = rtrim($sylvain_input_graph);

	# generate temp file
	 $tempFileName = tempnam($result_location,"Pathfinder_tmpGraph_");
	 $fh = fopen($tempFileName, 'w') or die("Can't open file $tempFileName");
	 fwrite($fh, $sylvain_input_graph);
	 fclose($fh);

   if($store_graph) {
   		echo "<br><align='left'>Your stored input graph has the id:<br> $graphid<br>
   		Submit this id to speed up other path finding jobs on this input graph.</align>";
   }
    echo "<hr>\n";
    if(strcmp($outputType,'pathsUnion') == 0 || strcmp($outputType,'pathsMarked') == 0 || strcmp($outputType,'pathsGraphs') == 0){
     echo "
     	To process your result with another tool, click one of the buttons listed below.
     	<br>
     	<br>
 	  <TABLE CLASS = 'nextstep'>
  		<TR>
      	<Th colspan = 3>
        	<a href = 'help.pathfinder.html#next'>Next steps</a>
      	</Th>
    	</TR>
    	<TR>
      	<TD>
        <FORM METHOD='POST' ACTION='display_graph_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($sylvain_input_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>
            <input type='hidden' NAME='eccol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Display the graph'>
         </form>
        </td>
        <TD>
        <FORM METHOD='POST' ACTION='visant.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='visant_graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='visant_graph_format' VALUE='$sylvain_input_format'>
          <input type='hidden' NAME='visant_directed' VALUE='$directed'>
          <INPUT type='submit' value='Display the graph with VisANT'>
         </form>
        </td>
       <TD>
         <FORM METHOD='POST' ACTION='compare_graphs_form.php'>
           <input type='hidden' NAME='pipe' VALUE='1'>
           <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
           <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($sylvain_input_format == 'tab') {
            echo "
             <input type='hidden' NAME='scol' VALUE='1'>
             <input type='hidden' NAME='tcol' VALUE='2'>
             <input type='hidden' NAME='wcol' VALUE='3'>";
          }
          echo "
          <INPUT type='submit' value='Compare this graph to another one'>
         </form>
       </td>
       <TD>
        <FORM METHOD='POST' ACTION='random_graph_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($sylvain_input_format == 'tab') {
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
        <FORM METHOD='POST' ACTION='pathfinder_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$file_location'>
          <input type='hidden' NAME='in_format' VALUE='$out_format'>";
          echo "
          <INPUT type='submit' value='Do path finding on this graph'>
         </form>
        </td>
       <TD>
         <FORM METHOD='POST' ACTION='graph_get_clusters_form.php'>
           <input type='hidden' NAME='pipe' VALUE='1'>
           <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
           <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($sylvain_input_format == 'tab') {
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
          <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($sylvain_input_format == 'tab') {
            echo "
             <input type='hidden' NAME='scol' VALUE='1'>
             <input type='hidden' NAME='tcol' VALUE='2'>
             <input type='hidden' NAME='wcol' VALUE='3'>";
           }
           echo "
          <INPUT type='submit' value='Node degree computation'>
         </form>
       </td>
     </tr>
     <tr>
      <TD>
        <FORM METHOD='POST' ACTION='convert_graph_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>";
          }
          echo "
          <INPUT type='submit' value='Convert $sylvain_input_format to another format'>
        </form>
      </td>
       <TD>
        <FORM METHOD='POST' ACTION='graph_neighbours_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>";
          }
          echo "
          <INPUT type='submit' value='Neighbourhood analysis'>
        </form>
      </td>
       <TD>
        <FORM METHOD='POST' ACTION='mcl_form.php'>
          <input type='hidden' NAME='pipe' VALUE='1'>
          <input type='hidden' NAME='graph_file' VALUE='$tempFileName'>
          <input type='hidden' NAME='graph_format' VALUE='$sylvain_input_format'>";
          if ($out_format == 'tab') {
            echo "
            <input type='hidden' NAME='scol' VALUE='1'>
            <input type='hidden' NAME='tcol' VALUE='2'>";
          }
          echo "
          <INPUT type='submit' value='MCL Graph clustering'>
        </form>
      </td>
     </tr>
   </table>";
  		}
  	}
  }
?>
</body>
</html>