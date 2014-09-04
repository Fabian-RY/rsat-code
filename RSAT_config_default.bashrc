################################################################
## This file is a template : please adapt the path [RSAT_PARENT_PATH]
## to your local configuration (should be the directory in which the
## rsat folder is installed.

################################################################ 
## Configuration for Regulatory Sequence Analysis Tools (RSAT)
export RSAT=[RSAT_PARENT_PATH]/rsat
export RSAT_SITE=localhost
export RSAT_WWW=http://localhost/rsat
export RSAT_WS=http://localhost/rsat
export PATH=${RSAT}/bin:${PATH}
export PATH=${RSAT}/perl-scripts:${PATH}
export PATH=${RSAT}/perl-scripts/parsers:${PATH}
export PATH=${RSAT}/python-scripts:${PATH}

################################################################
## Class path for metabolic pathway analysis tools
if  [ ${CLASSPATH} ]; then
       export CLASSPATH=${CLASSPATH}:${RSAT}/java/lib/NeAT_javatools.jar
else
       export CLASSPATH=.:${RSAT}/java/lib/NeAT_javatools.jar
fi

################################################################
## Use ssh as remote shell for CVS (required to install Ensembl API)
export CVS_RSH=ssh

################################################################
## Default path for the Ensembl Perl modules and sofwtare tools
export ENSEMBL_RELEASE=76
export ENSEMBLGENOMES_BRANCH=23
export PATH=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl-git-tools/bin:${PATH}
export PERL5LIB=${RSAT}/lib/bioperl-release-${BIOPERL_VERSION}/bioperl-live::${PERL5LIB}
export PERL5LIB=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl/modules::${PERL5LIB}
export PERL5LIB=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl-compara/modules::${PERL5LIB}
export PERL5LIB=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl-external/modules::${PERL5LIB}
export PERL5LIB=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl-functgenomics/modules::${PERL5LIB}
export PERL5LIB=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl-tools/modules::${PERL5LIB}
export PERL5LIB=${RSAT}/lib/ensemblgenomes-${ENSEMBLGENOMES_BRANCH}-${ENSEMBL_RELEASE}/ensembl-variation/modules::${PERL5LIB}
