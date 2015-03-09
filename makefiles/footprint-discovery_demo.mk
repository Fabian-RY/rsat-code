################################################################
## Demonstration for the too footprint-discovery

include ${RSAT}/makefiles/util.mk
MAKEFILE=${RSAT}/makefiles/footprint-discovery_demo.mk

ORG=Escherichia_coli_K_12_substr__MG1655_uid57779
TAXON=Enterobacteriales
GENE=lexA
QUERY=-q ${GENE}
BATCH=
TASK=query_seq,filter_dyads,orthologs,ortho_seq,purge,dyads,maps,gene_index,index

list_param:
	@echo "Parameters"
	@echo "ORG		${ORG}"
	@echo "TAXON		${TAXON}"
	@echo "GENE		${GENE}"
	@echo "QUERY		${QUERY}"
	@echo "TASK		${TASK}"
	@echo "SKIP		${SKIP}"
	@echo "LAST		${LAST}"
	@echo "BATCH		${BATCH}"
	@echo "FP_DISCO_DIR	${FP_DISCO_DIR}"

## Generic command for footprint-discovery (will be adapted in other
## targets by changing parameters).
FP_DISCO_DIR=results/footprint-discovery_demo
_fp_disco:
	@mkdir -p ${FP_DISCO_DIR}
	@echo
	@echo "Running footprint-discovery 	${ORG}	${TAXON}	${QUERY}"
	footprint-discovery -v ${V} -org ${ORG} -taxon ${TAXON} \
		${QUERY} \
		-sep_genes \
		-lth occ 1 \
		-lth occ_sig 0 \
		-uth rank 50 \
		-return occ,proba,rank \
		-filter \
		-bg_model taxfreq \
		-task ${TASK} ${BATCH} ${OPT} \
		-o ${FP_DISCO_DIR}

################################################################
## Run footprint discovery with selected genes
##
## THIS FAILS HERE:  &InitQueryOutput(), footprint.lib.pl line389
YEAST_DEMO_GENES=${RSAT}/public_html/demo_files/footprint-discovery_selected_yeast_genes.tab
fp_disco_selected_genes_yeast:
	@echo "Selected genes	${YEAST_DEMO_GENES}"
	@${MAKE} _fp_disco QUERY='-genes ${YEAST_DEMO_GENES}' \
		ORG=Saccharomyces_cerevisiae \
		TAXON=Saccharomycetales \
		TASK=query_seq,filter_dyads,orthologs,ortho_seq,purge,dyads,maps,gene_index,index,network,gene_index,network_index

################################################################
## Run footprint-discovery with one selected gene
fp_disco_one_gene: list_param
	@${MAKE} _fp_disco QUERY='-q ${GENE}'

## Run footprint discovery with all the genes of the genome of
## interest. This costs several hours of computation, it should better
## run on a cluster with the option -batch (see target
## fp_disco_all_genes_batch) or with a resricted number of genes
## (target fp_disco_gene_slice).
fp_disco_all_genes: list_param
	@${MAKE} _fp_disco  QUERY='-all_genes'

## Run the analysis of each gene of a genome in batch. This requires a
## PC cluster and a properly configured job manager (see cluster
## options in RSAT_config.props).
fp_disco_all_genes_batch: list_param
	@${MAKE} fp_disco_all_genes BATCH='-batch'

## Run footprint discovery for a limited number of genes amon all the
## genes of the genome (for quick tests and debugging)
SKIP=0
LAST=25
fp_disco_gene_slice: list_param
	@${MAKE} fp_disco_all_genes OPT='-skip ${SKIP} -last ${LAST}'

