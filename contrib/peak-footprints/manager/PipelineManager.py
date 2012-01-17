
from processor.ProcessorFactory import ProcessorFactory

from manager.Component import Component
from manager.PipelineXMLParser import PipelineXMLParser
from manager.ProgressionManager import ProgressionManager
from manager.PipelineListener import PipelineListener

from utils.Constants import Constants
from utils.FileUtils import FileUtils
from utils.RSATUtils import RSATUtils
from utils.MotifUtils import MotifUtils
from utils.exception.ExecutionException import ExecutionException
from utils.exception.ParsingException import ParsingException
from utils.exception.ConfigException import ConfigException
from utils.log.Log import Log
from utils.log.ListenerLog import ListenerLog

import sys, os, shutil, time, threading

# This class is the central manager. It's role is to manage the pipelines execution.
# It reads the definition of the pipelines from the XML file, create the corresponding object structure,
# verify it and execute it's steps.

class PipelineManager:

    SERVER_QUEUE_FILE_NAME = "serverQueue.txt"

    # --------------------------------------------------------------------------------------
    def __init__( self):
        
        self.config = {}
        config_path = None
        # Test if the project is installed in RSAT
        if Constants.RSAT_PATH_ENV_VAR in os.environ.keys():
            config_path = os.environ[ Constants.RSAT_PATH_ENV_VAR]
            if config_path != None and len( config_path) > 0:
                config_path = os.path.join( config_path, Constants.PROJECT_PATH_IN_RSAT)
                if not os.path.exists( config_path):
                    print "Project not installed in RSA-Tools"
                    config_path = None
        
        # If Project is not in RSAT, test if the project as its own environment variable set
        if (config_path == None or len( config_path) == 0 ) and (Constants.PROJECT_INSTALL_PATH_ENV_VAR in os.environ.keys()):
            config_path = os.environ[ Constants.PROJECT_INSTALL_PATH_ENV_VAR]
        
        # Test if a config_path has been found. If not, take the current working dir as path
        if config_path != None and len( config_path) > 0:
            self.config[ Constants.INSTALL_DIR_PARAM] = config_path
        else:
            print "PipelineManager.init : No " + Constants.PROJECT_INSTALL_PATH_ENV_VAR + " environment variable set : using current directory"
            self.config[ Constants.INSTALL_DIR_PARAM] = os.getcwd()
            
        self.readConfig( os.path.join( self.config[ Constants.INSTALL_DIR_PARAM], Constants.MANAGER_CONFIG_FILE_NAME))
        
        self.initVariables()
        
        self.serverQueue = []
        self.serverQueueLock = threading.Lock()
        self.ListenerThread = None


    # --------------------------------------------------------------------------------------
    # Read the manager parameters from the given file
    def readConfig(self, param_file):
        
        try:
            file = open( param_file, "r")
            for line in file:
                if line.isspace() or line[0] == Constants.COMMENT_CHAR:
                    continue
                tokens = line.split( "=")
                if tokens !=  None and len( tokens) == 2:
                    if tokens[1][-1] == "\n":
                        value = tokens[1][:-1]
                    else:
                        value = tokens[1]
                    self.config[ tokens[0].lower()] = value
                else:
                    raise ConfigException( "PipelineManager.readConfig : wrongly formated parameter line in config file '" + param_file + "'. Should be '<param_name>=<param_value>' instead of '" + line + "'")
        except IOError,  io_exce:
            raise ConfigException( "PipelineManager.readConfig : unable to read parameters from config file '" + param_file + "'. From:\n\t---> " + str( io_exce))


    # --------------------------------------------------------------------------------------
    # Initialize some variables
    def initVariables( self):

        # Add the RSAT path to the base output dir path retrieved from the manager.props
        self.config[ Constants.BASE_OUTPUT_DIR_PARAM] = os.path.join( self.getParameter( Constants.RSAT_DIR_PARAM), self.getParameter( Constants.BASE_OUTPUT_DIR_PARAM)) 
        
        # Add the RSAT path to the listening dir path retrieved from the manager.props
        self.config[ Constants.LISTENING_DIR_PARAM] = os.path.join( self.getParameter( Constants.RSAT_DIR_PARAM), self.getParameter( Constants.LISTENING_DIR_PARAM)) 

        # Set the path used by the RSATUtils class
        RSATUtils.RSAT_PATH = self.getParameter( Constants.RSAT_DIR_PARAM)        
        #jaspar_path = os.path.join( RSATUtils.RSAT_PATH, "public_html/data/motif_databases/JASPAR")
        #RSATUtils.RSAT_JASPAR_MOTIF_DATABASE = os.path.join( jaspar_path, self.getParameter( Constants.RSAT_JASPAR_MOTIF_DATABASE_PARAM))
        
        # Set the path to the Jaspar TF details files
        MotifUtils.JASPAR_FLAT_DB_PATH = os.path.join( self.getParameter( Constants.INSTALL_DIR_PARAM), "resources/jaspar/motif")

    
    # --------------------------------------------------------------------------------------
    # Manage the direct execution of the given pipelines definition
    def execute(self, pipelines_filepath, verbosity=0, resume = False, working_dir=None):
        
        self.addToQueue( pipelines_filepath, verbosity, str( resume), working_dir)
        return self.executePipelines()



    # --------------------------------------------------------------------------------------
    # Set the mamanger in server mode, always running and managing queue
    def server(self, listener_path = None):
        
        # initialize logs and output directories
        FileUtils.createDirectory( self.config[ Constants.BASE_OUTPUT_DIR_PARAM])
        self.config[ Constants.OUTPUT_DIR_PARAM] = os.path.join( self.getParameter( Constants.BASE_OUTPUT_DIR_PARAM), Constants.OUTPUT_DIR_NAME)
        FileUtils.createDirectory( self.config[ Constants.OUTPUT_DIR_PARAM])

        # init the server queue with queue file if exists (restoring from previous run)
        self.initServerQueue()
        
        # Init the logs of the listener
        ListenerLog.initLog( self.getParameter( Constants.OUTPUT_DIR_PARAM), 1)
        
        # Retrieve the path of the directory to listen
        if listener_path == None or len( listener_path) == 0:
            listener_path = self.getParameter( Constants.LISTENING_DIR_PARAM)
        
        # Launch the listener thread
        self.ListenerThread = threading.Thread( None, PipelineListener.start, "PipelineListener", ( self, listener_path, ))
        self.ListenerThread.start()
        
        # Wait for new entries in the queue
        while True:
            self.executePipelines()
            while len( self.serverQueue) == 0:
                time.sleep(5)


    # --------------------------------------------------------------------------------------
    # Adds a pipelines definition and params in queue
    def addToQueue( self, pipelines_filepath, verbosity, resume, working_dir):
        
        self.serverQueueLock.acquire()
        
        if pipelines_filepath != None and len( pipelines_filepath) > 0:
            self.serverQueue.append( (pipelines_filepath, resume, verbosity, working_dir))

        try:
            self.outputServerQueue()
        except ExecutionException, exe_exce:
            raise ExecutionException(" PipelineManager.addToQueue : Unable to add element in server queue. From:\n\t---> " + str( exe_exce))
        finally:
            self.serverQueueLock.release()
    
    
    
    # --------------------------------------------------------------------------------------
    # remove the first entry in the pipeline queue
    def removeFirstInQueue(self):
        
        self.serverQueueLock.acquire()
        
        if len( self.serverQueue) > 0:
            self.serverQueue = self.serverQueue[1:]
        
        try:
            self.outputServerQueue()
        except ExecutionException, exe_exce:
            raise ExecutionException(" PipelineManager.removeFirstInQueue : Unable to remove first element in server queue. From:\n\t---> " + str( exe_exce))
        finally:
            self.serverQueueLock.release()
        


    # --------------------------------------------------------------------------------------
    # Output the Pipeline queue to file
    def outputServerQueue(self):
        
        try:
            queue_file_path = os.path.join( self.config[ Constants.INSTALL_DIR_PARAM], PipelineManager.SERVER_QUEUE_FILE_NAME)
            queue_file = open( queue_file_path, "w")
            for infos in self.serverQueue:
                for info in infos:
                    queue_file.write( str(info) + "\t")
                queue_file.write("\n")
                queue_file.flush()
            queue_file.close()
        except IOError, io_exce:
            raise ExecutionException(" PipelineManager.outputServerQueue : Unable to save Server queue to file : " + queue_file_path +". From:\n\t---> " + str( io_exce))

    
    # --------------------------------------------------------------------------------------
    # Read the server queue file content to initialize the queue
    def initServerQueue(self):
        
        queue_file_path = os.path.join( self.config[ Constants.INSTALL_DIR_PARAM], PipelineManager.SERVER_QUEUE_FILE_NAME)
        if os.path.exists( queue_file_path):
            try:
                commands_list = []
                file = open( queue_file_path, "r")
                for line in file:
                    command_params = [None, 0, "True", None]
                    if not line.isspace() and line[0] != Constants.COMMENT_CHAR:
                        tokens = line.split()
                        if len( tokens) > 0 and len( tokens) <= 4:
                            for index in range( len( tokens)):
                                command_params[ index] = tokens[ index]
                        print "PipelineManager.initServerQueue : Adding command to queue : " + str( command_params)
                        commands_list.append( command_params)
                file.close()
                for command_params in commands_list:
                    self.addToQueue( command_params[0], command_params[1], command_params[2], command_params[3])
            except IOError, io_exce:
                raise ExecutionException(" PipelineManager.initServerQueue : Unable to read Server queue from file : " + queue_file_path +". From:\n\t---> " + str( io_exce))
            


    # --------------------------------------------------------------------------------------
    # Read the pipelines definition from the queue and execute them
    def executePipelines( self):
        
        result = True
        
        while len( self.serverQueue) > 0:
            
            params = self.serverQueue[0]
            pipelines_filepath = params[0]
            resume = (params[1].lower() == "true")
            try:
                verbosity = int( params[2])
            except ValueError:
                verbosity = 1
            working_dir = params[3]
            
            # Modifies the config if required and initialize logs and outputdirectory
            if working_dir != None and len( working_dir) > 0:
                self.config[ Constants.BASE_OUTPUT_DIR_PARAM] = working_dir
            FileUtils.createDirectory( self.config[ Constants.BASE_OUTPUT_DIR_PARAM])
                
            self.config[ Constants.OUTPUT_DIR_PARAM] = os.path.join( self.getParameter( Constants.BASE_OUTPUT_DIR_PARAM), Constants.OUTPUT_DIR_NAME)
            FileUtils.createDirectory( self.config[ Constants.OUTPUT_DIR_PARAM])
            Log.switchFiles( self.getParameter( Constants.OUTPUT_DIR_PARAM), verbosity)
            
            # Parse the XML file to retrieve the pipelines definition
            Log.trace( "#################################################################################")
            Log.trace( "# PipelineManager.executePipelines : Reading pipelines from : " + pipelines_filepath)
            Log.trace( "#################################################################################")
            
            try:
                pipelines = PipelineXMLParser.getPipelines( pipelines_filepath)
            except SyntaxError,  syn_exce:
                raise ParsingException( "PipelineManager.executePipelines : Unable to read definition of pipelines from XML file: '" + pipelines_filepath + "'. From:\n\t---> " + str( syn_exce))
            except ParsingException, par_exce:
                raise ParsingException( "PipelineManager.executePipelines : Unable to read definition of pipelines from XML file: '" + pipelines_filepath + "'. From:\n\t---> " + str( par_exce))
                
            if pipelines == None or len( pipelines) == 0:
                raise ParsingException( "PipelineManager.executePipelines : No pipeline defined in the given definition file : " + pipelines_filepath)
            
            # Verify if the definition of pipelines is correct
            Log.trace( "PipelineManager.executePipelines : Verifying pipelines")
            try:
                self.verifyPipelinesDefinition( pipelines)
            except ParsingException, exe_exce:
                raise ParsingException( "PipelineManager.executePipelines : Canceling execution of pipelines. From:\n\t---> " + str( exe_exce))

            # Initialize the ProgressionManager
            ProgressionManager.initialize( pipelines, self.getParameter( Constants.OUTPUT_DIR_PARAM), self.getParameter( Constants.INSTALL_DIR_PARAM))

            # Execute the pipelines
            Log.trace( "**************************************************")
            Log.trace( "# Starting Pipelines" )
            Log.trace( "**************************************************")
            
            for pipeline in pipelines:
                Log.trace("--------------------------------------------------------------------------")
                Log.trace("# Starting pipeline '" + pipeline.name + "'")
                Log.trace("--------------------------------------------------------------------------")
                pipeline_output = os.path.join( self.getParameter( Constants.OUTPUT_DIR_PARAM), pipeline.name)
                # Manage the pipeline output directory and the logs
                if resume == False:
                    shutil.rmtree( pipeline_output, True)
                    os.mkdir( pipeline_output)
                    Log.switchFiles( pipeline_output)
                else:
                    FileUtils.createDirectory( pipeline_output)
                    Log.initLog( pipeline_output)
                ProgressionManager.setPipelineStatus( pipeline, ProgressionManager.RUNNING_STATUS)
                shutil.copy( os.path.join( self.config[ Constants.INSTALL_DIR_PARAM], os.path.join( Constants.PROGRESSION_XSL_PATH, Constants.PROGRESSION_XSL_FILE)), pipeline_output)

                # Fill the queue with the pipeline first components
                component_queue_list = pipeline.firstComponents
                try:
                    # Execute the components in the queue
                    while len( component_queue_list) > 0:
                        index = 0
                        
                        # Seach the first component in queue that can be executed
                        while index < len( component_queue_list) and not component_queue_list[ index].canStart():
                            index += 1
                            
                        # If no executable component is found in the queue, pipeline is aborted
                        if index >= len( component_queue_list):
                            raise ExecutionException( "PipelineManager.executePipelines : No more component can be executed.")
                            
                        # If an executable component is found, starting it    
                        current_component = component_queue_list[index]
                        Log.trace( "##")
                        Log.trace( "## Starting component '" + current_component.getComponentPrefix() + "'")
                        if resume:
                            Log.trace("## Resume mode")
                        else:
                            Log.trace("## Forcing mode")
                        Log.trace( "##")
                        
                        # Execute the component
                        try:
                            executed = current_component.start( pipeline_output, self.config, resume)
                        except ExecutionException, exe_exce:
                            Log.log( "PipelineManager.executePipelines : Aborting execution of component : '" + current_component.getComponentPrefix() + "' . From:\n\t---> " + str( exe_exce))
                            
                        # If the component was not correctly executed, its next component are not passed to queue
                        if not executed:
                             Log.log( "PipelineManager.executePipelines : Component : '" + current_component.getComponentPrefix + "' was not executed. See logs for more details")
                        else:
                            # remove the component from queue and add its following component to the queue start (depth-first execution)
                            component_queue_list.remove( current_component)
                            components_to_add = []
                            for next_component in current_component.nextComponents:
                                if not next_component in component_queue_list:
                                    components_to_add.append( next_component)
                            component_queue_list[ :0] = components_to_add
                    
                except ExecutionException, exe_exce:
                    ProgressionManager.setPipelineStatus( pipeline, ProgressionManager.FAILED_STATUS)
                    Log.log( "PipelineManager.executePipelines : Aborting execution of pipeline : '" + pipeline.name + "' . From:\n\t---> " + str( exe_exce))
                    result = False
                
                # Verify if the pipeline log file contains errors. In such case, warns the user
                if Log.isLogEmpty() == False:
                    ProgressionManager.setPipelineStatus( pipeline, ProgressionManager.FINISHED_ERROR_STATUS)
                    Log.switchFiles( self.getParameter( Constants.OUTPUT_DIR_PARAM))
                    Log.log( "PipelineManager.executePipelines : WARNING : pipeline '" + pipeline.name + "' ended with errors. See log file for more details")
                    Log.trace("--------------------------------------------------------------------------")
                    Log.trace("# Pipeline '" + pipeline.name + "' ended with errors. See logs for more details")
                    Log.trace("--------------------------------------------------------------------------")
                    result = False
                else:
                    ProgressionManager.setPipelineStatus( pipeline, ProgressionManager.FINISHED_STATUS)
                    Log.switchFiles( self.getParameter( Constants.OUTPUT_DIR_PARAM))
                    Log.trace("--------------------------------------------------------------------------")
                    Log.trace("# Pipeline '" + pipeline.name + "' ended normaly")
                    Log.trace("--------------------------------------------------------------------------")
            
            Log.trace( "**************************************************")
            Log.trace( "# Pipelines finished" )
            Log.trace( "**************************************************")
            
            self.removeFirstInQueue()

        
        return result



    # --------------------------------------------------------------------------------------
    # Verify if, for each pipeline, the chain of input/output CommStruct
    # of component pipeline's component processors is coherent
    def verifyPipelinesDefinition( self, pipelines):


        for pipeline in pipelines:
            try:
                for component in pipeline.componentList:
                    # Get the input CommStruct class
                    processor_class_info = ProcessorFactory.decomposeProcessorName( component.processorName)
                    __import__( processor_class_info[0])
                    current_input = getattr( sys.modules[ processor_class_info[0]], processor_class_info[1]).getInputCommStructClass()
                    # get the previous components output CommStruct class
                    previous_outputs = []
                    for previous_component in component.previousComponents:
                        previous_processor_class_info = ProcessorFactory.decomposeProcessorName( previous_component.processorName)
                        __import__( previous_processor_class_info[0])
                        output = getattr( sys.modules[ previous_processor_class_info[0]], previous_processor_class_info[1]).getOutputCommStructClass()
                        if output != None:
                            previous_outputs.extend( output)
                    if len( previous_outputs) == 0:
                        previous_outputs = None
                    # compare input and ouput CommStructs
                    if current_input != None:
                        correct = False
                        if previous_outputs != None:
                            for input in current_input:
                                if input in previous_outputs:
                                    correct = True
                        else:
                            if component.getParameter( Component.INPUT_FILE_PARAM, False) == None:
                                raise ParsingException( "PipelineManager.verifyPipelinesDefinition : Definition error in pipeline '" + pipeline.name + "' : processor '" + component.processorName + "' inputs one of'" + str(current_input) + " and has no input structure nor input file")
                            else:
                                correct = True
                    else:
                        correct = True
                    if not correct:
                        raise ParsingException( "PipelineManager.verifyPipelinesDefinition : Definition error in pipeline '" + pipeline.name + "' : processor '" + component.processorName + "' inputs one of '" + str( current_input) + " while previous processor output one of '" + str( previous_outputs))
                    # verify if the processor required parameters are correctly set
                    required_parameter_list = getattr( sys.modules[ processor_class_info[0]], processor_class_info[1]).getRequiredParameters()
                    if required_parameter_list != None:
                        for param_name in required_parameter_list:
                            param = component.getParameter( param_name, False)
                            if param == None:
                                raise ParsingException( "PipelineManager.verifyPipelinesDefinition : Definition error in pipeline '" + pipeline.name + "' : processor '" + component.processorName + "' require the parameter '" + str( param_name))
                                
            except ParsingException, exce:
                raise ParsingException( "PipelineManager.verifyPipelinesDefinition : Unable to verify pipeline '" + pipeline.name + "' definition. From:\n\t---> " + str(exce))
        


    # --------------------------------------------------------------------------------------
    # Return the value of the parameter if exists
    def getParameter(self, param_name, mandatory = True):
        
        try:
            param_value =  self.config[ param_name]
            return param_value
        except (TypeError, KeyError), key_exce:
            if mandatory:
                raise ExecutionException( "PipelineManager.getParameter : Config parameter :'" + param_name + "' does not exists. From:\n\t---> " + str( key_exce))
            else:
                return None
                
# eflag: FileType = Python2
