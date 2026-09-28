# Replay files independently of Shiny, including failed sensitivity scenarios.
sc_replay <- function(record) {
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
  sc_calculate(record$inputs)
}
sc_without_time <- function(x) {
  if(is.list(x)) {
    x$generated_at<-NULL
    x<-lapply(x,sc_without_time)
  }
  x
}

