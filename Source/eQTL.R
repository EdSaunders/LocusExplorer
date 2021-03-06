#add barplot - Transcripts
ggplot(ROIdatEQTL(),
       aes(xmin=START,xmax=END,ymin=0,ymax=DIRECTION)) +
  geom_hline(aes(yintercept=0),linetype="dashed",col="grey80") +
  geom_rect(col="#A71930",fill="#A71930") +
  scale_y_continuous(limits=c(-1,1),
                     breaks=c(0),
                     labels=udf_pad("eQTL"),
                     name="xxx") +
  xlim(c(zoomStart(),zoomEnd())) +
  udf_theme()
  
# x <- read.table("CIDR_GWAS_LocusExplorerData/chr3_EQTL.txt",header=TRUE)
# str(x)
# 
# ggplot(x,
#        aes(xmin=START,xmax=END,ymin=0,ymax=DIRECTION)) +
#   geom_hline(aes(yintercept=0),linetype="dashed",col="grey80") +
#   geom_rect(col="#A71930",fill="#A71930") +
#   scale_y_continuous(limits=c(-1,1),
#                      breaks=c(0),
#                      labels=udf_pad("eQTL"),
#                      name="xxx") +
#   #xlim(c(zoomStart(),zoomEnd())) +
#   udf_theme()
