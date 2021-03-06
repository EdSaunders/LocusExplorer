# Workspace ---------------------------------------------------------------


# Define Server -----------------------------------------------------------
shinyServer(function(input, output, session) {  
  
  source("source/UDF.R",local = TRUE)
  
  regions <- read.csv("Data/ProstateData/regions.csv") %>% 
    mutate(REGIONBED=paste0(CHR,"_",START,"_",END))
  

  # Data level 1 - Raw Input ------------------------------------------------
  datStats <- reactive({
    switch(input$dataType,
           Prostate = {
             fread(paste0("Data/ProstateData/LE/",input$RegionID,"_assoc.txt"),
                   header=TRUE, data.table=FALSE)
             },
           Custom = {
             #input file check
             validate(need(input$FileStats != "", "Please upload file"))
             
             inFile <- input$FileStats
             if(is.null(inFile)){return(NULL)}
             fread(inFile$datapath, header=TRUE, data.table=FALSE) 
           },
           Example = {
             fread("Data/CustomDataExample/Association.txt",
                   header=TRUE, data.table=FALSE)
           })
  })
  
  datLD <- reactive({
    switch(input$dataType,
           Prostate = {
             #input file check
             validate(need(input$RegionID != "", "Please select RegionID"))
             fread(paste0("Data/ProstateData/LE/",input$RegionID,"_LD.txt"),
                    header=TRUE, data.table=FALSE)
             },
           Custom = {
             #input file check
             validate(need(input$FileLD != "", "Please upload file"))
             
             inFile <- input$FileLD
             if(is.null(inFile)){return(NULL)}
             fread(inFile$datapath, header=TRUE, data.table=FALSE)
           },
           Example = {
             fread("Data/CustomDataExample/LD.txt",
                   header=TRUE, data.table=FALSE) 
           })
  })
  
  datLNCAP <- reactive({
    switch(input$dataType,
           Prostate = {
             #input file check
             validate(need(input$RegionID != "", "Please select RegionID"))
             fread(paste0("Data/ProstateData/LE/",input$RegionID,"_LNCAP.txt"),
                   header=TRUE, data.table=FALSE)
             },
           Custom = {
             #input file check
             validate(need(input$FileLNCAP != "", "Please upload file"))
             
             inFile <- input$FileLNCAP
             if(is.null(inFile)){return(NULL)}
             fread(inFile$datapath, header=TRUE, data.table=FALSE) 
           },
           Example = {
             fread("Data/CustomDataExample/LNCAP.txt",
                   header=TRUE, data.table=FALSE) 
           })
  })
  
  datEQTL <- reactive({
    switch(input$dataType,
           Prostate = {
             #input file check
             validate(need(input$RegionID != "", "Please select RegionID"))
             fread(paste0("Data/ProstateData/LE/",input$RegionID,"_EQTL.txt"),
                   header=TRUE, data.table=FALSE)
             },
           Custom = {
             #input file check
             validate(need(input$FileEQTL != "", "Please upload file"))
             
             inFile <- input$FileEQTL
             if(is.null(inFile)){return(NULL)}
             fread(inFile$datapath, header=TRUE, data.table=FALSE)
           },
           Example = {
             fread("Data/CustomDataExample/eQTL.txt",
                   header=TRUE, data.table=FALSE) 
           })
  })
  
  # Define ROI --------------------------------------------------------------
  RegionFlank <- reactive({
    if(input$Flank==""){rf <- 10000}else{rf <- input$Flank}
    as.numeric(rf)
  })
  RegionChr <- reactive({ datStats()$CHR[1] })
  RegionChrN <- reactive({
    x <- gsub("chr","",RegionChr())
    as.numeric(ifelse(x=="X","23",x))
    })
  RegionStart <- reactive({ 
    x <- datStats() %>% 
      filter(CHR==RegionChr() &
               !is.na(BP)) %>% 
      .$BP %>% min 
    #round down to 10K bp
    as.integer(max(0,round((x-RegionFlank())/RegionFlank()) * RegionFlank()))
    #as.integer(max(0,round((x-10000)/10000) * 10000))
    })
  RegionEnd <- reactive({ 
    x <- datStats() %>% 
      filter(CHR==RegionChr() &
               !is.na(BP)) %>% 
      .$BP %>% max 
    #round up to 10K bp
    as.integer(round((x+RegionFlank())/RegionFlank()) * RegionFlank())
    #as.integer(round((x+10000)/10000) * 10000)
    })
  RegionHits <- reactive({ 
    #CHR_A	BP_A	SNP_A	CHR_B	BP_B	SNP_B	R2
    #maximum LD SNPs is 5
    d <- datLD() %>% .$SNP_A %>% unique %>% sort
    d[1:min(length(d),15)] })
  
  RegionHitsSelected <- reactive({input$HitSNPs})
  
  # Genetic Map 1KG ---------------------------------------------------------
  datGeneticMap <- reactive({
    fread(paste0("Data/GeneticMap1KG/genetic_map_",
                 RegionChr(),
                 "_combined_b37.txt"),
          header=TRUE, sep=" ", data.table = FALSE)  %>% 
      transmute(BP=position,
                Recomb=`COMBINED_rate(cM/Mb)`,
                RecombAdj=Recomb*ROIPLogMax()/100)})
  
  # Data level 2 - ROI ------------------------------------------------------
  ROIdatStats <- reactive({ datStats() %>% 
      filter(BP>=RegionStart() &
               BP<=RegionEnd()) %>% 
      mutate(PLog=-log10(P)) })
  ROIdatLD <- reactive({ datLD() %>% 
      filter(CHR_B==as.numeric(gsub("chr","",RegionChr())) &
               BP_B>=RegionStart() &
               BP_B<=RegionEnd()) })
  ROIdatLNCAP <- reactive({ datLNCAP() %>% 
      filter(CHR==RegionChr() &
               BP>=RegionStart() &
               BP<=RegionEnd()) })
  ROIdatEQTL <- reactive({ datEQTL() %>% 
      filter(CHR==RegionChr() &
               START>=RegionStart() &
               END<=RegionEnd()) })
  ROIdatGeneticMap <- reactive({ datGeneticMap() %>% 
      filter(BP>=RegionStart() &
               BP<=RegionEnd()) })
  ROIPLogMax <- reactive({
    #ylim Max for plotting Manhattan
    maxY <- max(ROIdatStats()$PLog,na.rm = TRUE)
    return(max(10,ceiling((maxY+1)/5)*5))
  })
  
  # Define Zoom Start End ---------------------------------------------------
  zoomStart <- reactive({ input$BPrange[1] })
  zoomEnd <- reactive({ input$BPrange[2] })
  
  
  # Data level 3 - Plot data ------------------------------------------------
  # http://stackoverflow.com/a/8197703/680068
  # hcl(h=seq(15, 375, length=6), l=65, c=100)[1:5]
  # colors match first 5 colours of default ggplot2
  colourLD5 <- c("#F8766D","#A3A500","#00BF7D","#00B0F6","#E76BF3")
  #create pallete LD 0 to 100
  colLD <- lapply(colourLD5,function(i)colorRampPalette(c("grey95",i))(100))
  
  plotDatManhattan <- reactive({
    Stats <- 
      ROIdatStats() %>% 
      filter(BP>=zoomStart() &
               BP<=zoomEnd() &
               PLog >= input$FilterMinPlog)
    
    
    LD <- ROIdatLD() %>% 
      filter(
        R2 >= input$FilterMinLD &
          SNP_A %in% RegionHitsSelected())
    
    #assign colours to LD 
    d_LD <- base::do.call(rbind,
                          lapply(RegionHitsSelected(), function(snp){
                            d <- LD %>% filter(SNP_A == snp)
                            #LD round minimum is 1 max 100
                            LDColIndex <- ifelse(round(d$R2,2)==0,1,round(d$R2,2)*100)
                            LDColIndex <- ifelse(LDColIndex>100,100,LDColIndex)
                            d$LDSNP <- snp
                            d$LDSmoothCol <- colLD[[match(snp,RegionHitsSelected())]][100]
                            d$LDCol <- colLD[[match(snp,RegionHitsSelected())]][LDColIndex]
                            
                            #d$LDSmoothCol <- colLD[[match(snp,RegionHits())]][100]
                            #d$LDCol <- colLD[[match(snp,RegionHits())]][LDColIndex]
                            return(d)
                          }))
    # to add smooth LD Y value used for Pvalue and LD 0-1
    # add pvalues for Y value on the plot
    d_LD <- 
      base::merge.data.frame(
        Stats,
        d_LD[,c("BP_B","R2","LDSNP","LDSmoothCol","LDCol")],
        by.x="BP",by.y="BP_B",all.x=TRUE) %>% 
      mutate(R2_Adj=ROIPLogMax()*R2)
    
    
    return(d_LD)
  })
  
  #subset of recombination rates for zoomed region
  plotDatGeneticMap <- reactive({ datGeneticMap() %>% 
      filter(BP>=zoomStart() &
               BP<=zoomEnd()) })
  
  #get granges collapsed genes for ggplot+ggbio
  plotDatGene <- reactive({ 
    udf_GeneSymbol(chrom=RegionChr(),
                   chromStart=zoomStart(),
                   chromEnd=zoomEnd()) })
  
  #number of genes in zoomed region
  plotDatGeneN <- reactive({ 
    res <- try({
      length(unique(plotDatGene()@elementMetadata$gene_id))}, silent=TRUE)
    if(class(res)=="try-error"){res <- 1}
    return(res)
    })
  
  
  # Output ------------------------------------------------------------------
  # Output Summary ----------------------------------------------------------
  output$SummaryStats <- renderDataTable({ datStats() %>% arrange(BP) }) 
  output$SummaryLD <- renderDataTable({ datLD() %>% group_by(SNP_A) %>% arrange(BP_B) })
  output$SummaryLNCAP <- renderDataTable({ datLNCAP() %>% arrange(BP) })
  output$SummaryEQTL <- renderDataTable({ datEQTL() %>% arrange(START) })
  
  output$SummaryRegion <- renderTable({ 
    data.frame(Chr=RegionChr(),
               Start=RegionStart(),
               End=RegionEnd(),
               Size=RegionEnd()-RegionStart(),
               Hits=paste(RegionHits(),collapse=", "))})
  
  output$SummaryFileNrowNcol <- renderTable({ 
    data.frame(InputFile=c("Association","LD","LNCAP","eQTL"),
               Nrow=c(nrow(datStats()),nrow(datLD()),
                      nrow(datLNCAP()),nrow(datEQTL())),
               Ncol=c(ncol(datStats()),ncol(datLD()),
                      ncol(datLNCAP()),ncol(datEQTL()))
    )})
  
  #output$SummaryHeadPlotStats <- renderTable({head(plotDatStats())})
  #output$SummaryHeadPlotDatManhattan <- renderDataTable({plotDatManhattan()})
  #output$SummaryDimPlotDatManhattan <- renderTable({as.data.frame(dim(plotDatManhattan()))})
  #output$SummaryplotDatManhattan <- renderTable({plotDatManhattan()})
  #output$SummaryROIdatEQTL <- renderTable({as.data.frame(ROIdatEQTL())})
  #output$SummaryRegionFlank <- renderText({RegionFlank()})
  #output$SummaryZoom <- renderText({paste(zoomStart(),zoomEnd(),sep="-")})
  
  # Plot --------------------------------------------------------------------
  #Plot Chr ideogram
  plotObjChromosome <- reactive({source("source/Chromosome.R",local=TRUE)})
  output$PlotChromosome <- renderPlot({print(plotObjChromosome())})
  #Manhattan track
  plotObjManhattan <- reactive({source("source/Manhattan.R",local=TRUE)})
  output$PlotManhattan <- renderPlot({print(plotObjManhattan())})
  #SNPType track
  plotObjSNPType <- reactive({source("source/SNPType.R",local=TRUE)})
  output$PlotSNPType <- renderPlot({print(plotObjSNPType())})
  #SNP LD track
  plotObjSNPLD <- reactive({source("source/LD.R",local=TRUE)})
  output$PlotSNPLD <- renderPlot({print(plotObjSNPLD())})
  #LNCAP Smooth track
  plotObjLNCAP <- reactive({source("source/LNCAP.R",local=TRUE)})
  output$PlotLNCAP <- renderPlot({print(plotObjLNCAP())})
  #eQTL bar track
  plotObjEQTL <- reactive({source("source/eQTL.R",local=TRUE)})
  output$PlotEQTL <- renderPlot({print(plotObjEQTL())})
  #Gene track
  plotObjGene <- reactive({source("source/Gene.R",local=TRUE)})
  output$PlotGene <- renderPlot({print(plotObjGene())})
  
  # Plot Merge --------------------------------------------------------------
  #Dynamic size for tracks
  RegionHitsCount <- reactive({ length(RegionHitsSelected()) })
  RegionGeneCount <- reactive({ plotDatGeneN() })
  RegionSNPTypeCount <- reactive({ length(unique(plotDatManhattan()$TYPED)) })
  
  #Default size per track
  trackSize <- reactive({ 
    data.frame(Track=c("Chromosome","Manhattan","LD","SNPType","LNCAP","eQTL","Gene"),
               Size=c(100,400,
                      RegionHitsCount()*30,
                      RegionSNPTypeCount()*30,
                      30,
                      30,
                      RegionGeneCount()*30)) })

  #Create subset based on selected tracks
  trackHeights <- reactive({
    trackSize() %>% filter(Track %in% input$ShowHideTracks) %>% .$Size })
  trackColours <- reactive({ 
    cbind(trackHeights(),c('grey90','grey80'))[,2][1:length(trackHeights())] })
  
  #output plot
  # See Dynamic UI section
  
  # Output to a file --------------------------------------------------------
  # Get the selected download file type.
  downloadPlotType <- reactive({input$downloadPlotType})
  
  observe({
    plotType    <- input$downloadPlotType
    plotTypePDF <- plotType %in% c("pdf","svg")
    plotUnit    <- ifelse(plotTypePDF, "inches", "pixels")
    plotUnitDefHeight <- ifelse(plotTypePDF, 12, 1200)
    plotUnitDefWidth <- ifelse(plotTypePDF, 10, 1000)
    
    updateNumericInput(
      session,
      inputId = "downloadPlotHeight",
      label = sprintf("Height (%s)", plotUnit),
      value = plotUnitDefHeight)
    
    updateNumericInput(
      session,
      inputId = "downloadPlotWidth",
      label = sprintf("Width (%s)", plotUnit),
      value = plotUnitDefWidth)
  })
  
  
  # Get the download dimensions.
  downloadPlotHeight <- reactive({
    input$downloadPlotHeight
  })
  
  downloadPlotWidth <- reactive({
    input$downloadPlotWidth
  })
  
  # Get the download file name.
  downloadPlotFileName <- reactive({
    input$downloadPlotFileName
  })
  
  # Include a downloadable file of the plot in the output list.
  output$downloadPlot <- downloadHandler(
    filename = function() {
      paste(downloadPlotFileName(), downloadPlotType(), sep=".")   
    },
    # The argument content below takes filename as a function
    # and returns what's printed to it.
    content = function(con) {
      # Gets the name of the function to use from the 
      # downloadFileType reactive element. Example:
      # returns function pdf() if downloadFileType == "pdf".
      plotFunction <- match.fun(downloadPlotType())
      plotFunction(con, width = downloadPlotWidth(), height = downloadPlotHeight())
      print(plotObjMerge())
      dev.off(which=dev.cur())
    }
  )
  
  
  # Dynamic UI --------------------------------------------------------------
  #Zoom to region X axis BP
  output$BPrange <-
    renderUI({
      sliderInput("BPrange", h5("Region: Start-End"),
                  min = RegionStart(),
                  max = RegionEnd(),
                  value = c(RegionStart(),RegionEnd()),
                  step = 20000)})
  #Input BED style for zoom, eg.: chr2:100-200
  output$RegionZoom <- renderUI({
    textInput("RegionZoom", label = h5("Region zoom"),
              value = "chr:start-end")
              #value = paste0(RegionChr(),":",RegionStart(),"-",RegionEnd()))
    })
  
  #Select hit SNPs
  output$HitSNPs <- 
    renderUI({
      checkboxGroupInput("HitSNPs", "Hit SNPs",
                         RegionHits(),
                         #select max of 5 SNPs
                         selected = 1:min(5,length(RegionHits())))
      })
  
  output$RegionID <- renderUI({
    selectInput(inputId="RegionID", label= h5("RegionID"), 
                choices=regions %>% filter(CHR==input$Chr) %>% .$REGIONBED,
                selected=1)})
  
  
  #download file name - default: chr_start_end
  output$downloadPlotFileName <- renderUI({
    textInput(
      inputId = "downloadPlotFileName",
      label = "Download file name",
      value = paste(RegionChr(),zoomStart(),zoomEnd(),sep="_"))})
  #download plot title - default: chr_start_end
  output$downloadPlotTitle <- renderUI({
    textInput(
      inputId = "downloadPlotTitle",
      label = "Plot title",
      value = paste(RegionChr(),zoomStart(),zoomEnd(),sep="_"))})
  
  
  
  #merged plot with dynamic plot height
  plotObjMerge <- reactive({source("Source/MergePlots.R",local=TRUE)})
  output$plotMerge <- renderPlot({print(plotObjMerge())})
  output$plotMergeUI <- renderUI({
    plotOutput("plotMerge",width=800,height=sum(trackHeights()))
    })
  
  # Observe update ----------------------------------------------------------
  # maximum of 5 SNPs can be selected to display LD, minimum 1 must be ticked.
  observe({
    if(length(input$HitSNPs) > 5){
      updateCheckboxGroupInput(session, "HitSNPs", selected= head(input$HitSNPs,5))}
    if(length(input$HitSNPs) < 1){
      updateCheckboxGroupInput(
        session, "HitSNPs",
        selected= RegionHits()[1:min(5,length(RegionHits()))])}
    if(length(input$ShowHideTracks) < 1){
      updateCheckboxGroupInput(session, "ShowHideTracks", selected= "Manhattan")}
  })
  observeEvent(input$RegionZoom,({
    if(!input$RegionZoom %in% c("chr:start-end","")){
      newStartEnd <- as.numeric(unlist(strsplit(input$RegionZoom,":|-"))[2:3])
      updateSliderInput(session, "BPrange",
                        value = newStartEnd)}
    }))
  
  
  
  
})#END shinyServer

