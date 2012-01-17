
import os, shutil

from processor.Processor import Processor
from processor.io.BedSeqAlignmentStatsCommStruct import BedSeqAlignmentStatsCommStruct

from common.BEDSequence import BEDSequence

from utils.log.Log import Log
from utils.MotifUtils import MotifUtils
from utils.exception.ExecutionException import ExecutionException

# This processor produce a BED format file containing all the identified motif with their coordinate and their score.
# A color is also associated to each motif (see below).
# This BED file can be opened in the UCSC genome browser.
#
# Parameters:
#   ReferenceMotif: the motif used as reference
#   Method : the method used to assign a color to the motifs. Value should be "family" or "score"
#            - the "family" method assign a color for each motif family. Note that following the UCSC recommendation only
#              8 colors are assigned , so some families can have the same colors.
#            - the "score" method assign a color to the motif according to its score. The greater the score, the clearer the color
#              Note that in this case the color is the same for each motif.
#            Note: in both cases, the reference motif is assigned to black color
#   ScoreMin : the minimum value the score can reach
#   ScoreMax : the maximum value the score can reach

class BEDOutputProcessor( Processor):
    
    REFERENCE_MOTIF = "ReferenceMotif"
    COLOR_METHOD = "ColorMethod"
    COLOR_METHOD_FAMILY = "family"
    COLOR_METHOD_SCORE = "score"
    SCORE_MIN = "ScoreMin"
    SCORE_MAX = "ScoreMax"
    
    COLORS = [ "0,0,255", "0,255,255", "0,255,0", "255,255,0", "255,0,0"]

    
    # --------------------------------------------------------------------------------------
    def __init__( self):
        Processor.__init__( self)

    # --------------------------------------------------------------------------------------
    # Returns the name of the CommStruct class used as input 
    # (None if no input CommStruct)
    @staticmethod
    def getInputCommStructClass():
        
        return ( BedSeqAlignmentStatsCommStruct, )


    # --------------------------------------------------------------------------------------
    # Returns the name of the CommStruct class used as output
    # (None if no output CommStruct)
    @staticmethod
    def getOutputCommStructClass():
        
        return ( BedSeqAlignmentStatsCommStruct, )


    # --------------------------------------------------------------------------------------
    # Returns a name that will be used as display name in the user friendly outputs
    @staticmethod
    def getDisplayName():
        
        return "Export identified motifs to BED formated file"


    # --------------------------------------------------------------------------------------
    # Returns a list of parameters names that are required parameters for the corresponding processor
    @staticmethod
    def getRequiredParameters():
        
        return ( BEDOutputProcessor.SCORE_MIN, BEDOutputProcessor.SCORE_MAX)


    # --------------------------------------------------------------------------------------
    # Execute the processor
    def execute( self, input_commstructs):
        
        if input_commstructs == None or len( input_commstructs) == 0:
            raise ExecutionException( "BEDOutputProcessor.execute : No inputs")
        
        input_commstruct = input_commstructs[0]
        
        # Retrieve the processor parameters
        reference_motif = self.getParameter( BEDOutputProcessor.REFERENCE_MOTIF)
                
        color_method = self.getParameter( BEDOutputProcessor.COLOR_METHOD,  False)
        if color_method == None:
            color_method = BEDOutputProcessor.COLOR_METHOD_SCORE
        else:
            color_method = color_method.lower()
            if color_method != BEDOutputProcessor.COLOR_METHOD_SCORE and color_method != BEDOutputProcessor.COLOR_METHOD_FAMILY:
                color_method = BEDOutputProcessor.COLOR_METHOD_SCORE
                
        score_min = self.getParameterAsfloat( BEDOutputProcessor.SCORE_MIN)
        score_max = self.getParameterAsfloat( BEDOutputProcessor.SCORE_MAX)
        
        # Prepare the processor output dir
        out_path = os.path.join( self.component.outputDir, self.component.getComponentPrefix())
        shutil.rmtree( out_path, True)
        os.mkdir( out_path)

        # Retrieve the JASPAR motifs details
        motif_details = MotifUtils.getMotifsDetailsFromJaspar()
        motif_id = motif_details[ 0]
        motif_family = motif_details[ 1]
        family_rgb = {}

        # build the bed output file path
        bed_file_path = os.path.join( out_path, self.component.pipelineName + "_Motifs.bed")

        try:
            bed_file = open(bed_file_path,  "w")

            bed_file.write( "track name='" + self.component.pipelineName + "' visibility=3 itemRgb='On' use_score=1\n")
            bed_file.write( "browser dense RSAT\n")
            bed_file.write( "browser dense\n") 
            bed_file.write( "## seq_name	start	end	feature_name	score	strand	thickStart	thickEnd	itemRgb	blockCount	blockSizes	blckStarts\n")

            current_color = None
            bedseq_list = input_commstruct.bedToMA.keys()
            bedseq_list.sort( BEDSequence.compare)
            previous_line_start = 0
            previous_line_key = ""
            for bed_seq in bedseq_list:
                for msa in input_commstruct.bedToMA[ bed_seq]:
                    for motif in msa.motifs:
                        motif_name = motif.name
                        if not input_commstruct.motifStatistics.has_key( motif_name):
                            continue
                        if motif_name in motif_id.keys():
                            out_name = motif_id[ motif_name]
                            chromosom = bed_seq.chromosom
                            start_position = bed_seq.indexStart + msa.fixIndex( motif.indexStart)
                            end_position = bed_seq.indexStart + msa.fixIndex( motif.indexEnd)
                            score = motif.score
                            
                            # Back is assigned to the reference motif
                            if motif_name == reference_motif:
                                item_rgb = "0,0,0"
                            # for the other motif, color depends on the chosen method
                            else:
                                if color_method == BEDOutputProcessor.COLOR_METHOD_FAMILY:
                                    if motif_name in motif_family.keys():
                                        item_rgb = self.getNextFamilyColor( motif_family[ motif_name], family_rgb, current_color)
                                        current_color = item_rgb
                                    else:
                                        item_rgb = BEDOutputProcessor.COLORS[ 0]
                                else:
                                    item_rgb = self.getColorForScore( score, score_min, score_max)
                            
                            # Write the lines to output file
                            line_out = chromosom
                            line_out += "\t" + str( start_position)
                            line_out += "\t" + str( end_position)
                            line_out += "\t" + out_name
                            line_out += "\t" + str( int( score*1000))
                            line_out += "\t" + motif.strand
                            line_out += "\t" + str( start_position)           # ThickStart
                            line_out += "\t" + str( end_position)            # ThickEnd
                            line_out += "\t" + item_rgb        # itemRGB
                            #line_out += "\t" + "0"            # BlockCount
                            #line_out += "\t" + "0"            # BlockSizes
                            #line_out += "\t" + "0"            # BlockStarts
                            
                            # Build a key that represent the motif chrom,  name and positions
                            line_key = chromosom + ":" + str( start_position) + ":" + str( end_position) + ":" + out_name
                            
                            # If the new line has the same key has the previous one, we must keep only one of the two lines
                            # i.e. the one with the highest score (the tell() and seek() method permits to overwrite the old line
                            # line if required.
                            # If the new line and the previous one has different keys the new line is simply written
                            if previous_line_key != line_key:
                                previous_line_start = bed_file.tell()
                                bed_file.write( line_out)
                                bed_file.write( "\n")
                                bed_file.flush
                                previous_line_key = line_key
                                previous_score = score
                            else:
                                if score > previous_score:
                                    bed_file.seek( previous_line_start)
                                    bed_file.write( line_out)
                                    bed_file.write( "\n")
                                    bed_file.flush
                                    previous_score = score     

            bed_file.close()
            input_commstruct.paramStatistics[ BedSeqAlignmentStatsCommStruct.BED_OUTPUT_PATH] = bed_file_path
        except IOError, io_exce:
            Log.log( "BEDOutputProcessor.execute : Unable to save the BED file of recognized motifs : " + str( io_exce))
        
        return input_commstruct
        
        

    # --------------------------------------------------------------------------------------
    # Assign a color to the motif family if required and return this color
    def getNextFamilyColor(self, family, family_rgb, current_color):
        
        if not family in family_rgb.keys():
            if current_color == None:
                family_rgb[ family] = BEDOutputProcessor.COLORS[ 0]
            else:
                current_color_index = BEDOutputProcessor.COLORS.index( current_color)
                next_color_index = current_color_index + 1
                if next_color_index < len( BEDOutputProcessor.COLORS) :
                    next_color = BEDOutputProcessor.COLORS[ next_color_index]
                else:
                    next_color = BEDOutputProcessor.COLORS[ 0]
                family_rgb[ family] = next_color
            
        return family_rgb[ family]
        
        
        
    # --------------------------------------------------------------------------------------
    # Assign a color according to the given score 
    def getColorForScore( self, score, score_min, score_max):
        
        # Color = RED proportionnal to score 
        ##level = int( ((score - score_min) / float( score_max - score_min)) *100) + 155
        ##return str(level) + ",0,0"
        
        # Color = purple, blue, yellow, green, orange, red respect to the score
        return self.COLORS[ int((score - score_min) / float( score_max - score_min) * len( self.COLORS))]
        
