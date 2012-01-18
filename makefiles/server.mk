############################################################
#
# $Id: server.mk,v 1.33 2012/01/18 05:53:14 rsat Exp $
#
# Time-stamp: <2003-10-10 22:49:55 jvanheld>
#
############################################################

#RSAT=${HOME}/rsa-tools/
include ${RSAT}/makefiles/util.mk
MAKEFILE=${RSAT}/makefiles/server.mk

GENBANK_DIR=/home/rsa/downloads/ftp.ncbi.nih.gov/genbank/genomes
NCBI_DIR=/home/rsa/downloads/ftp.ncbi.nih.gov/genomes

DATE = `date +%Y%m%d_%H%M%S`


#################################################################
# programs

WGET = wget -np -rNL 
MAKE=nice -n 19 make -s -f ${MAKEFILE}
RSYNC_OPT = -ruptvl ${OPT}
SSH=-e 'ssh -x'
RSYNC = rsync ${RSYNC_OPT} ${SSH}

################################################################
# Mirrors
BIGRE=rsat@rsat.ulb.ac.be:rsa-tools
WWWSUP=rsat@wwwsup.scmbb.ulb.ac.be:rsa-tools
MAMAZE=rsat@mamaze.ulb.ac.be:rsa-tools
CCG=jvanheld@itzamna.ccg.unam.mx:rsa-tools
#CCG=jvanheld@mitzli.ccg.unam.mx:rsa-tools
TAGC=jvanheld@139.124.66.43:rsa-tools
UPPSALA=jvanheld@bongcam1.hgen.slu.se:rsa-tools
PRETORIA=jvanheld@anjie.bi.up.ac.za:.
MIRROR_SERVERS=${MAMAZE} ${WWWSUP} ${UPPSALA} ${CCG} 
LOG_SERVERS=${MAMAZE}  ${BIGRE} ${WWWSUP} ${UPPSALA} ${CCG} ${PRETORIA}

################################################################
## OLD SERVERS, NOT MAINTAINED ANYMORE
#FLYCHIP=jvanheld@flychip.org.uk:rsa-tools
#TORONTO=jvanheld@ws03.ccb.sickkids.ca:rsa-tools
#PRETORIA=jvanheld@milliways.bi.up.ac.za:rsa-tools

################################################################
## distribution
MEDICEL=root@grimsel.co.helsinki.fi:/work/programs/rsa-tools

MIRROR=${UPPSALA}

################################################################
#### from brol to mirrors
################################################################
DIR=perl-scripts
DIRS=perl-scripts public_html doc
rsync_mirrors:
	@for mirror in ${MIRRORS} ; do					\
		${MAKE} rsync_one_mirror MIRROR=$${mirror} DIR=$${dir} ;	\
	done

rsync_one_mirror:
	@for dir in ${DIRS}; do							\
		${MAKE} rsync_dir  MIRROR=${MIRROR} DIR=$${dir} ;	\
	done

EXCLUDED=						\
	--exclude '*~'					\
	--exclude data					\
	--exclude tmp					\
	--exclude logs					\
	--exclude perl-scripts/lib/arch			\
	--exclude qd.pl				
rsync_dir:
	@echo "Synchronizing dir ${DIR} to mirror ${MIRROR}"
	${RSYNC} ${OPT} ${EXCLUDED}		\
		${DIR} ${MIRROR}/

DATA_EXCLUDED= --exclude 'Mus_*'		\
	--exclude 'Homo_*'			\
	--exclude 'Rattus_*'			\
	--exclude comparative_genomics		\
	--exclude upstream_calibrations

RSYNC_DATA_CMD=${RSYNC} ${DATA_EXCLUDED} \
	public_html/data  ${MIRROR}/public_html/ 
rsync_data:
	@for mirror in ${MIRRORS} ; do					\
		${MAKE} rsync_data_one_mirror MIRROR=$${mirror} ;	\
	done

rsync_data_one_mirror:
	@echo "Synchronizing data to mirror ${MIRROR}" 
	@echo ${RSYNC_DATA_CMD} ;			
	${RSYNC_DATA_CMD};				


ORGS=Saccharomyces_cerevisiae Escherichia_coli_K12 Bacillus_subtilis
medicel:
	${RSYNC} config/medicel.config ${MEDICEL}/config/
	${RSYNC} doc/*.pdf ${MEDICEL}/doc/
	rsync ${SSH} -ruptvL distrib/* ${MEDICEL}/perl-scripts
	for org in ${ORGS}; do				\
		${RSYNC} data/$${org} ${MEDICEL}/data/;	\
	done

rsync_archives:
	@for mirror in ${MIRRORS} ; do				\
		${RSYNC} archives/* $${mirror}/archives/ ;	\
	done

################################################################
#### from mirrors to brol
################################################################
rsync_logs:
	@for mirror in ${LOG_SERVERS} ; do					\
		echo "${RSYNC} $${mirror}/logs/log-file_* logs/" ;	\
		${RSYNC} $${mirror}/logs/log-file_* logs/ ;		\
	done
	rsync -ruptvl -e 'ssh -p 24222'  jvanheld@139.124.66.43:rsa-tools/logs/log-file_* logs/


rsync_config:
	@for mirror in ${MIRROR_SERVERS} ; do \
		${RSYNC} $${mirror}/config/*.config config/ ;\
	done

FOLDERS=data pdf_files
from_ucmb:
	@for folder in ${FOLDERS}; do \
		${RSYNC} jvanheld@${PAULUS}:rsa-tools/$${folder} . ; \
	done

FOLDERS=data 
from_cifn:
	@for folder in ${FOLDERS}; do \
		${RSYNC} jvanheld@${CCG}:rsa-tools/$${folder}/* ./$${folder} ; \
	done


################################################################
## Clean temporary directory
CLEAN_LIMIT=3
clean_tmp:
	@echo "Cleaning temporary directory	`hostname` ${RSAT}/public_html/tmp/"
	@echo
	@date "+%Y/%m/%d %H:%M:%S"
	@echo "Free disk before cleaning" 
	@df -h ${RSAT}/public_html/tmp/
	@echo
	@date "+%Y/%m/%d %H:%M:%S"
	@echo "Measuring disk usage before cleaning"
	@echo "Before cleaning	" `du -sh public_html/tmp`
	@touch ${RSAT}/public_html/tmp/
	@echo
	@date "+%Y/%m/%d %H:%M:%S"
	@echo "Removing all files older than ${CLEAN_LIMIT} days"
	find ${RSAT}/public_html/tmp/ -mtime +${CLEAN_LIMIT} -type f -exec rm -f {} \;	
	@echo
	@date "+%Y/%m/%d %H:%M:%S"
	@echo "Measuring disk usage after cleaning"
	@echo "After cleaning	" `du -sh public_html/tmp`
	@echo "Cleaned temporary directory" | mail -s 'cleaning tmp' ${RSAT_ADMIN_EMAIL}
	@echo
	@date "+%Y/%m/%d %H:%M:%S"
	@echo "Free disk after cleaning" 
	@df -h ${RSAT}/public_html/tmp/



