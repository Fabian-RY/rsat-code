################################################################
## Manage RSAT tasks on a PC cluster

#include ${RSAT}/makefiles/util.mk
include ${RSAT}/makefiles/init_RSAT.mk
MAKEFILE=${RSAT}/makefiles/cluster.mk


list_nodes:
	@echo "NODES"
	@echo ${NODES}

################################################################
## Specific setting for compiling RSAT on the cluster@bigre
NODE_TASK=compile_all
compile_nodes:
	${MAKE} iterate_nodes NODES='${COMPILE_NODES}' NODE_CMD='cd ${RSAT}; make -f makefiles/init_RSAT.mk compile_all BIN=/usr/local/bin' 

## Run a command on a single node
NODE_CMD=hostname
NODE=n57
one_node:
	@echo "NODE=${NODE}	NODE_CMD=${NODE_CMD}"
	@ssh ${NODE} '${NODE_CMD}'


## Run a task on a list of nodes
iterate_nodes:
	@for node in ${NODES} ; do \
		${MAKE} NODE=$${node} one_node ; \
	done


