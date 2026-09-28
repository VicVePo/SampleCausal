# Replay files independently of Shiny, including failed sensitivity scenarios.
sc_replay <- function(record) {
  # Historical replay is explicit and isolated; it is not a new public recommendation.
  if(sc_member(record$software_version,c("0.4.0","0.4.1","0.4.2","0.4.3","1.0.0"))) {
    archived<-new.env(parent=baseenv())
    # Resolve base-package statistical functions without inheriting current engine globals.
    parent.env(archived)<-as.environment("package:stats")
    for(k in c("SC_ROOT","SC_CONTRACT","SC_MODULES","SC_PRESENTATION"))assign(k,NULL,envir=archived)
    sys.source(file.path(SC_ROOT,paste0("R/archive/engine_",record$software_version,".R")),envir=archived)
    archived$sc_init(SC_ROOT)
    sys.source(file.path(SC_ROOT,paste0("R/archive/replay_",record$software_version,".R")),envir=archived)
    return(archived$sc_replay(record))
  }
  if(!is.null(record$software_version)&&!identical(record$software_version,SC_VERSION))
    stop("Versión sin motor de reproducción archivado; no se sustituye por la versión actual.")
  if(!is.null(record$rows)) {
    if(!is.null(record$base_scenario))
      return(sc_sensitivity(record$base_scenario,record$parameter,lapply(record$rows,function(row)row$value)))
    # Compatibility with early valid-only sensitivity exports.
    rows<-lapply(record$rows,function(row) {
      if(is.null(row$result$inputs)) stop("Este archivo antiguo no conserva las entradas de una fila inválida.")
      list(value=row$value,result=sc_calculate(row$result$inputs))
    })
    record$rows<-rows;return(record)
  }
  if(is.null(record$inputs)) stop("El archivo no contiene entradas reproducibles.")
  sc_calculate(record$inputs,research=isTRUE(record$research_only))
}
sc_without_time <- function(x) {
  if(is.list(x)) {
    x$generated_at<-NULL
    x<-lapply(x,sc_without_time)
  }
  x
}
