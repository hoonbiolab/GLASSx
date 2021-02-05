library(tidyverse)
library(odbc)
library(DBI)
library(grid)

#######################################################
rm(list=ls())
# Location of the SCGP single cell data
myinf1 <- "/projects/verhaak-lab/scgp/data/10x/10X-aggregation-20190905/RV18001-2-3-RV19001-2-4-5-6-7-8-9_20190827.Rds"

load(myinf1)

# Remove all cells with no expression
#sums <- apply(log2cpm, 2, sum)	
#range(sums)
# [1]  2453.769 45315.686
# No cells with 0 expression

# Remove QC genes:
qc_genes <- c("ENSGGENES","ENSGUMI","ENSGMITO", "ENSGSEQSAT","ENSGSAMP") 
log2cpm <- log2cpm[-which(rownames(log2cpm) %in% qc_genes),]
featuredata <- featuredata[-which(rownames(featuredata) %in% qc_genes),]

# Annotate clusters using previous definitions
clust_annot = tsne.data %>%
	rownames_to_column('cell') %>%
	filter(dbCluster == 2) %>%
	column_to_rownames('cell')
	
log2cpm_myeloid <- log2cpm[,rownames(clust_annot)]
	
# 	mutate(cell_type = recode(dbCluster, `1` = "differentiated_tumor",  `2` = "myeloid", `3` = "stemcell_tumor",
#                               `4` = "oligodendrocyte", `5` = "prolif_stemcell_tumor", `6` = "granulocyte", `7` = "endothelial",
#                               `8` = "t_cell", `9` = "pericyte", `10` = "fibroblast", `11` = "b_cell", `12` = "dendritic_cell")) %>%
# 	column_to_rownames('cell')

# clust_annot file and log2cpm files are in the same order so no need to match the order between them
# cell_type <- clust_annot[,"cell_type"]

# Assign each cell a subtype
# log2cpm_annot <- log2cpm
# colnames(log2cpm_annot) <- cell_type

# Get sample names
sample_id <- sapply(strsplit(rownames(clust_annot), "-"), "[[", 3)
sample_id <- recode(sample_id, "0" = "UC917", "1" = "SM001", "2" = "SM002", "3" = "SM004", "4" = "SM006",
					"5" = "SM011", "6" = "SM008", "7" = "SM012", "8" = "SM015", "9" = "SM017", "10" = "SM018")
clust_annot[,"sample_id"] <- sample_id
names(sample_id) <- rownames(clust_annot)

# Convert ensembl ID to gene symbol
featuredata <- featuredata[rownames(log2cpm_myeloid),]

gene <- featuredata[,"Associated.Gene.Name"]
names(gene) <- rownames(featuredata)

rownames(log2cpm_myeloid) <- gene

# Establish connection to db and get macrophage signature
con <- DBI::dbConnect(odbc::odbc(), "GLASSv3")
sigs <- dbReadTable(con, Id(schema = "ref", table = "immune_signatures"))
mac_sig <- sigs %>%
		filter(signature_set == "Muller") %>%
		filter(signature_name == "Macrophages") %>%
		.$gene_symbol

sc_mac_score <- apply(log2cpm_myeloid[mac_sig,],2,mean)
sample_id <- clust_annot[names(sc_mac_score),"sample_id"]
plot_res <- data.frame(names(sc_mac_score), sc_mac_score, sample_id)
colnames(plot_res) <- c("cell_id","sc_mac_score","sample_id")

# Read in bulk subtype results
con <- DBI::dbConnect(odbc::odbc(), "scgp")

bulk_res <- dbReadTable(con, Id(schema = "analysis", table="transcriptional_subtype"))
bulk_mes <- bulk_res %>% 
			filter(signature_name == "Mesenchymal") %>%
			mutate(sample_id = sapply(strsplit(aliquot_barcode,"-"),function(x)paste(x[2],x[3],sep=""))) #%>%
			#filter(sample_id %in% c("SM006","SM012","SM017","SM018","SM011"))

plot_res <- plot_res %>% 
group_by(sample_id) %>% 
summarise(mean = mean(sc_mac_score)) %>% 
ungroup() %>%
inner_join(bulk_mes, by = "sample_id") %>%
as.data.frame()


pdf("/projects/verhaak-lab/GLASS-III/figures/analysis/myeloid_sc_bulk_macrophage_scatterplot.pdf",width=1.9,height=1.5)  
ggplot(plot_res, aes(x = mean, y = enrichment_score/1000)) +
geom_point() +
geom_smooth(method = lm, se = FALSE) + 
theme_classic() +
labs(x = "Mean myeloid cell macrophage score", y = "Bulk mes. score") +
theme(axis.text = element_text(size=7),
axis.title = element_text(size=7), 
panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
strip.background = element_blank(),
legend.position="none") #+
#coord_cartesian(xlim=c(-35, 35))
dev.off()

