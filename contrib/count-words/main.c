// 
//  main.c
//  count-words
//  
//  Created by Matthieu on 2008-11-04.
//  
// 

#include "utils.h"
#include "count.h"

int VERSION = 200811;

// ===========================================================================
// =                            usage & help
// ===========================================================================
void usage(char *progname)
{
    printf("usage: %s -l length [-i inputfile] [-h]\n", progname);
}

void help(char *progname)
{
    printf(
"NAME\n"
"        count-words\n"   
"\n"
"AUTHOR\n"
"        Matthieu Defrance\n"
"\n"
"DESCRIPTION\n"
"        calculates oligomer frequencies from a set of sequences\n"
"\n"
"CATEGORY\n"
"        sequences\n"
"        pattern discovery\n"
"\n"
"USAGE\n"
"        count-words -l length [-i inputfile]\n"
"\n"
"ARGUMENTS\n"
"    INPUT OPTIONS\n"
"        --version        print version\n"
"        -v #             change verbosity level (0, 1, 2)\n"
"        -l #             set oligomer length to #\n"
"        -2str            add reverse complement\n"
"        -1str            do not add reverse complement\n"
"        -noov            do not allow overlapping occurrences\n"
"        -grouprc         group reverse complement with the direct sequence\n"
"        -nogrouprc       do not group reverse complement with the direct sequence\n"
"\n"
"\n"

    );
}

// ===========================================================================
// =                            main
// ===========================================================================
int main(int argc, char *argv[])
{
    char *input_filename = NULL;
    char *output_filename = NULL;
    int add_rc = TRUE;
    int noov = FALSE;
    int oligo_length = 1;
    int grouprc = TRUE;
    
    // options
    if (argc == 1) 
    {
        usage(argv[0]);
        exit(0);
    }

    int i;
    for (i = 1; i < argc; i++) 
    {
        if (strcmp(argv[i], "--help") == 0) 
        {
            help(argv[0]);
            exit(0);
        } 
        else if (strcmp(argv[i], "--version") == 0) 
        {
            printf("%d\n", VERSION);
            exit(0);
        } 
        else if (strcmp(argv[i], "-v") == 0) 
        {
            ASSERT(argc > i + 1, "-v requires a nummber (0, 1 or 2)");
            VERBOSITY = atoi(argv[++i]);
            ASSERT(VERBOSITY >= 0 && VERBOSITY <= 2, "invalid verbosity level (should be 0, 1 or 2)");
        } 
        else if (strcmp(argv[i], "-h") == 0) 
        {
            help(argv[0]);
            exit(0);
        } 
        else if (strcmp(argv[i], "-1str") == 0) 
        {
            add_rc = FALSE;
        } 
        else if (strcmp(argv[i], "-2str") == 0) 
        {
            add_rc = TRUE;
        } 
        else if (strcmp(argv[i], "-noov") == 0) 
        {
            noov = TRUE;
        } 
        else if (strcmp(argv[i], "-grouprc") == 0) 
        {
            grouprc = TRUE;
        } 
        else if (strcmp(argv[i], "-nogrouprc") == 0) 
        {
            grouprc = FALSE;
        } 
        else if (strcmp(argv[i], "-l") == 0) 
        {
            ASSERT(argc > i + 1, "-l requires a nummber");
            oligo_length = atoi(argv[++i]);
        } 
        else if (strcmp(argv[i], "-i") == 0) 
        {
            ASSERT(argc > i + 1, "-i requires a string");
            input_filename = argv[++i];
        } 
        else if (strcmp(argv[i], "-o") == 0) 
        {
            ASSERT(argc > i + 1, "-o requires a string");
            output_filename = argv[++i];
        } 
        else 
        {
            ERROR("invalid option %s", argv[i]);
        }
    }

    FILE *input_fp = stdin;
    FILE *output_fp = stdout;
    if (input_filename) 
    {
        input_fp = fopen(input_filename, "r");
        if (!input_fp) 
        {
           ERROR("can not read from file '%s'", input_filename);
        }
    }
    if (output_filename) 
    {
       output_fp = fopen(output_filename, "w");
       if (!output_fp) 
       {
           ERROR("can not write to file '%s'", output_filename);
       }
    }

    count_in_file(input_fp, output_fp, oligo_length, add_rc, noov, grouprc, argc, argv);
    fflush(output_fp);
    if (input_filename)
        fclose(input_fp);
    if (output_filename)
        fclose(output_fp);
        
    return 0;
}
