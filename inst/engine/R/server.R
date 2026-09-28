# Public Shiny services: the research flag is never read from browser requests.
sc_config <- function() {
  modules<-Filter(function(m) m$id %in% SC_PUBLIC,SC_CONTRACT$modules)
  modules<-lapply(modules,function(m) {
    m$name<-SC_PRESENTATION$names[[m$id]];m$limitations<-as.list(c(unlist(SC_PRESENTATION$limitations[[m$id]]),sc_phase4_limitations(m$id)))
    if(m$id=="M02.table")m$estimands<-as.list(setdiff(unlist(m$estimands),"ATT"))
    m$reference<-SC_CONTRACT$sources[[m$source]];m
  })
  list(version=SC_VERSION,contract_version=SC_CONTRACT$version,modules=modules,
       labels=SC_PRESENTATION$labels,examples=Filter(function(p)!(p$module_id=="M02.table"&&p$estimand=="ATT"),sc_read_json(file.path(SC_ROOT,"data/examples.json"))))
}
sc_write_json <- function(value,path) {
  jsonlite::write_json(value,path,auto_unbox=TRUE,pretty=TRUE,digits=NA,null="null",na="null")
}
sc_save_result <- function(result,export_dir) {
  if(result$status!="ok") return(result)
  dir.create(export_dir,recursive=TRUE,showWarnings=FALSE)
  is_sensitivity<-!is.null(result$rows)
  prefix<-paste0(if(is_sensitivity) "sensibilidad_" else "escenario_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC"),"_")
  json_path<-tempfile(prefix,tmpdir=export_dir,fileext=".json")
  sc_write_json(result,json_path)
  output<-list(status="ok",saved_json=normalizePath(json_path,winslash="/"))
  if(!is_sensitivity) {
    text_path<-sub("\\.json$",".txt",json_path)
    full<-paste(result$justification,"\n\nREGISTRO COMPLETO\n",
                jsonlite::toJSON(result,auto_unbox=TRUE,pretty=TRUE,digits=NA,null="null"),sep="")
    writeLines(enc2utf8(full),text_path,useBytes=TRUE)
    output$saved_text<-normalizePath(text_path,winslash="/")
  }
  output
}
sc_dispatch <- function(route,payload=NULL,export_dir=file.path(SC_ROOT,"exports")) {
  if(!sc_member(route,c("/api/config","/api/calculate","/api/sensitivity","/api/save","/api/save-sensitivity")))
    return(list(status="out_of_scope",message="Operación no habilitada."))
  if(route=="/api/config") return(sc_config())
  if(!is.list(payload)||is.null(names(payload))) return(list(status="invalid_input",message="Solicitud inválida."))
  if(nchar(jsonlite::toJSON(payload,auto_unbox=TRUE,null="null"),type="bytes")>131072)
    return(list(status="invalid_input",message="La solicitud excede el tamaño admitido."))
  if(route %in% c("/api/calculate","/api/save")) result<-sc_calculate(payload) else
    result<-sc_sensitivity(payload$scenario,payload$parameter,payload$values)
  if(route %in% c("/api/save","/api/save-sensitivity")) sc_save_result(result,export_dir) else result
}
sc_make_server <- function(export_dir=file.path(SC_ROOT,"exports")) {
  force(export_dir)
  function(input,output,session) {
    files<-shiny::reactiveValues(json=NULL,text=NULL,sensitivity=NULL)
    register<-function(id,key,ctype) {
      output[[id]]<-shiny::downloadHandler(
        filename=function() {shiny::req(files[[key]]);basename(files[[key]])},
        content=function(file) {shiny::req(files[[key]]);if(!file.copy(files[[key]],file,overwrite=TRUE)) stop("Exportación no disponible.")},
        contentType=ctype
      )
      shiny::outputOptions(output,id,suspendWhenHidden=FALSE)
    }
    register("download_json","json","application/json; charset=utf-8")
    register("download_text","text","text/plain; charset=utf-8")
    register("download_sensitivity","sensitivity","application/json; charset=utf-8")
    shiny::observeEvent(input$sc_request,{
      req<-input$sc_request
      if(!is.list(req)||!is.character(req$id)||length(req$id)!=1L) return()
      result<-tryCatch(sc_dispatch(req$route,req$payload,export_dir),
                       error=function(e) list(status="numeric_failure",message="No se pudo completar la solicitud."))
      if(identical(result$status,"ok")&&!is.null(result$saved_json)) {
        if(identical(req$route,"/api/save-sensitivity")) files$sensitivity<-result$saved_json else {
          files$json<-result$saved_json;files$text<-result$saved_text
        }
      }
      session$sendCustomMessage("sc_response",list(id=req$id,
          json=as.character(jsonlite::toJSON(result,auto_unbox=TRUE,digits=NA,null="null"))))
    },ignoreInit=FALSE)
  }
}
