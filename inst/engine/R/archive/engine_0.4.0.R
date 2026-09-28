# SampleCausal: native R planning engine. No Shiny or Python dependency.
SC_VERSION <- "0.4.0"
SC_MAX_N <- 1e9
`%||%` <- function(x, y) if (is.null(x)) y else x
sc_read_json <- function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)
sc_init <- function(root) {
  SC_ROOT <<- normalizePath(root, winslash = "/", mustWork = TRUE)
  SC_CONTRACT <<- sc_read_json(file.path(SC_ROOT, "data/contract.json"))
  SC_MODULES <<- setNames(SC_CONTRACT$modules, vapply(SC_CONTRACT$modules, function(m) m$id, ""))
  SC_PRESENTATION <<- sc_read_json(file.path(SC_ROOT, "data/presentation.json"))
  invisible(TRUE)
}
SC_PUBLIC <- c("M01.weights","M01.adjusted_variance","M02.table","M03.normal","M06.prediction","M05.summary")
SC_KINDS <- c("pilot","publication","explicit_assumption","sensitivity_scenario")
sc_member <- function(x, allowed) is.character(x) && length(x)==1L && !is.na(x) && x %in% unlist(allowed)
sc_fail <- function(message, status="invalid_input", ...) {
  stop(structure(list(message=message,status=status,details=list(...),call=NULL),
                 class=c("sc_error","error","condition")))
}
sc_number <- function(p, key, low=NULL, high=NULL, closed_low=FALSE, closed_high=FALSE, integer=FALSE) {
  x <- p[[key]]
  label <- SC_PRESENTATION$labels[[key]] %||% key
  if (!is.numeric(x) || length(x)!=1L || !is.finite(x)) sc_fail(paste(label,"debe ser un número finito."),field=key)
  if ((!is.null(low) && if(closed_low) x<low else x<=low) ||
      (!is.null(high) && if(closed_high) x>high else x>=high))
    sc_fail(paste(label,"está fuera del intervalo permitido."),field=key)
  if (integer && x!=floor(x)) sc_fail(paste(label,"debe ser un entero."),field=key)
  as.numeric(x)
}
sc_text <- function(p,key) {
  x <- p[[key]]
  if (!is.character(x) || length(x)!=1L || is.na(x) || !nzchar(trimws(x)))
    sc_fail(paste("Falta documentar:",key),field=key)
  trimws(x)
}
sc_choice <- function(p,key,allowed) {
  if (!sc_member(p[[key]],allowed)) sc_fail(paste("Selección no admitida:",key),field=key)
  p[[key]]
}
sc_positive <- function(x,label="varianza") {
  if(length(x)!=1L || !is.finite(x) || x<=0)
    sc_fail(paste("No se pudo representar",label,"con precisión suficiente."),"numeric_failure")
  x
}
sc_log_gamma_ratio <- function(a) {
  if(a>1e4) {t<-1/a; return(-t/8+t^3/192-t^5/640)}
  lgamma(a+.5)-lgamma(a)-.5*log(a)
}
sc_beta_parameters <- function(r,phi) {
  target<-log(phi)
  f<-function(logk) {
    k<-exp(logk)
    sc_log_gamma_ratio(k*r)+sc_log_gamma_ratio(k*(1-r))-target
  }
  lo<--12;hi<-0
  for(i in seq_len(100)) {if(f(lo)<0) break;lo<-lo-2}
  for(i in seq_len(100)) {if(f(hi)>0) break;hi<-hi+2}
  if(!is.finite(f(lo)) || !is.finite(f(hi)) || f(lo)>=0 || f(hi)<=0)
    sc_fail("No se pudo encerrar la raíz de solapamiento.","numeric_failure")
  k<-exp(uniroot(f,c(lo,hi),tol=1e-12,maxiter=200,check.conv=TRUE)$root)
  a<-k*r;b<-k*(1-r)
  residual<-abs(exp(sc_log_gamma_ratio(a)+sc_log_gamma_ratio(b))-phi)
  if(residual>1e-8) sc_fail("La raíz de solapamiento no cumple la tolerancia.","numeric_failure")
  list(a=a,b=b,mu=digamma(a)-digamma(b),sigma2=trigamma(a)+trigamma(b),phi_residual=residual)
}
sc_normal_expectation <- function(fun,mu,s) {
  knots<-sort(unique(c(-Inf,-s,0,s,-mu/s,Inf)))
  total<-0;error<-0
  for(i in seq_len(length(knots)-1L)) {
    out<-integrate(function(z) fun(mu+s*z)*dnorm(z),knots[i],knots[i+1L],
                   abs.tol=1e-13,rel.tol=1e-11,subdivisions=150L,stop.on.error=FALSE)
    if(out$message!="OK") sc_fail("La integración no convergió.","numeric_failure")
    total<-total+out$value;error<-error+out$abs.error
  }
  if(!is.finite(total) || error>1e-8*max(abs(total),1e-8))
    sc_fail("La integral no cumple la precisión requerida.","numeric_failure")
  list(value=total,error=error)
}
sc_liu_variance <- function(r,phi,rho2,estimand) {
  if(phi==1) return(list(V=1/(r*(1-r)),info=list(constant_propensity=TRUE,rho2_interpretation="indefinida; rama constante")))
  info<-sc_beta_parameters(r,phi);mu<-info$mu;s2<-info$sigma2
  info$distribution<-"normal_moment_matched"
  log_base<-s2/2+abs(mu)+log1p(exp(-2*abs(mu)))-log(2)
  if(estimand=="ATE") {
    term<-log_base+log1p(rho2*s2)
    if(term>700) sc_fail("La varianza excede la representación numérica disponible.","numeric_failure")
    return(list(V=sc_positive(2*(1+exp(term))),info=info))
  }
  h<-switch(estimand,ATT=function(w) plogis(w),ATC=function(w) plogis(-w),
            ATO=function(w) plogis(w)*plogis(-w))
  s<-sqrt(s2);Hout<-sc_normal_expectation(h,mu,s);H<-sc_positive(Hout$value,"normalización de los pesos")
  if(Hout$error>1e-8*H) sc_fail("La normalización de pesos no tiene precisión suficiente.","numeric_failure")
  center<-sc_normal_expectation(function(w) w*h(w),mu,s)$value/H
  if(estimand %in% c("ATT","ATC")) {
    sign<-if(estimand=="ATT") 1 else -1
    factor<-rho2/s2*(s2+(mu+sign*s2-center)^2)+(1-rho2)
    logV<-sign*mu+s2/2+log(factor)-2*log(H)
    if(logV>700) sc_fail("La varianza excede la representación numérica disponible.","numeric_failure")
    V<-exp(logV)
  } else {
    moment<-sc_normal_expectation(function(w) (w-center)^2*h(w),mu,s)$value
    V<-(rho2*moment/s2+(1-rho2)*H)/H^2
  }
  info$H<-H;info$center<-center;info$integration_error_H<-Hout$error
  list(V=sc_positive(V),info=info)
}
sc_variance <- function(p,research=FALSE) {
  m<-p$module_id;info<-list();B<-0
  if(m %in% c("M01.weights","M01.adjusted_variance")) {
    r<-sc_number(p,"r",0,1)
    if(m=="M01.adjusted_variance") {
      q0<-sc_number(p,"q0",0);q1<-sc_number(p,"q1",0)
      if(!identical(p$q_definition,"M01_section6_sigma2_times_deff_with_remainder"))
        sc_fail("Confirma la definición específica de las varianzas de M01.",field="q_definition")
      sc_text(p,"pilot_definition");A<-q1/r+q0/(1-r)
    } else {
      d0<-sc_number(p,"D0",1,closed_low=TRUE);d1<-sc_number(p,"D1",1,closed_low=TRUE)
      if(p$outcome=="binary") {
        p0<-sc_number(p,"p0",0,1);p1<-sc_number(p,"p1",0,1)
        v0<-p0*(1-p0);v1<-p1*(1-p1)
      } else {v0<-sc_number(p,"sd0",0)^2;v1<-sc_number(p,"sd1",0)^2}
      A<-d1*v1/r+d0*v0/(1-r);info<-list(var0=v0,var1=v1)
    }
  } else if(m=="M02.table") {
    r<-sc_number(p,"r",0,1);cval<-sc_number(p,"c",.55,.95,TRUE,TRUE);scheme<-p$estimand
    if(scheme %in% c("MW","EW") && !research) sc_fail("Variante reservada para verificación interna.","disabled_variant")
    table<-SC_MODULES[[m]]
    allowed<-if(research) names(table$coefficients) else unlist(table$estimands)
    if(!sc_member(scheme,allowed)) sc_fail("Ponderación no habilitada.","out_of_scope")
    key<-sprintf("%.1f",r)
    if(abs(as.numeric(key)-r)>1e-12 || !key %in% names(table$prevalence_adjustment))
      sc_fail("Austin requiere una proporción tabulada: 0.1, 0.2, ..., 0.9.","out_of_scope",field="r")
    sd<-sc_number(p,"sd_common",0);coefs<-unlist(table$coefficients[[scheme]])
    j<-match(scheme,unlist(table$prevalence_adjustment_columns))
    vif<-exp(coefs[1]+coefs[2]*cval+coefs[3]*cval^2+table$prevalence_adjustment[[key]][[j]])
    if(vif<1) sc_fail("La tabla produce un VIF menor que 1; no se sustituye por 1.","incoherent_approximation",vif=vif)
    A<-sd^2*vif/(r*(1-r));info$vif<-vif
  } else if(m=="M03.normal") {
    r<-sc_number(p,"r",0,1);phi<-sc_number(p,"phi",0,1,closed_high=TRUE)
    rho2<-sc_number(p,"rho2",0,1,closed_low=TRUE);S<-sc_number(p,"S",0)
    if(!isTRUE(p$homogeneous_effect)) sc_fail("Esta ruta requiere declarar efecto homogéneo.","out_of_scope")
    if(phi==1 && rho2!=0) sc_fail("Con propensión constante usa la rama rho²=0.",field="rho2")
    v<-sc_liu_variance(r,phi,rho2,p$estimand);info<-v$info
    A<-S^2*v$V;info$standardized_variance<-v$V
  } else if(m=="M06.prediction") {
    n0<-sc_number(p,"n0",0,integer=TRUE);cov<-sc_number(p,"p",0,closed_low=TRUE,integer=TRUE)
    v0<-sc_number(p,"residual_var0",0);v1<-sc_number(p,"residual_var1",0)
    if(n0<=cov+1) sc_fail("Los controles deben superar p + 1.",field="n0")
    A<-v1+v0*cov/(n0-cov-1);B<-v0/n0+v0*cov/(n0*(n0-cov-1))
  } else if(m %in% c("M07.scalar","M07.bootstrap_summary")) {
    sc_text(p,"pilot_definition");scale<-sc_choice(p,"effect_scale",c("mean_difference","log_marginal_OR"))
    if((p$outcome=="binary")!=(scale=="log_marginal_OR")) sc_fail("La escala no coincide con el desenlace.",field="effect_scale")
    if(m=="M07.scalar") A<-sc_number(p,"V_stable",0) else {
      xs<-p$V_bootstrap
      if(!is.list(xs) && !is.numeric(xs)) sc_fail("Se requiere un vector bootstrap finito y positivo.")
      valid<-vapply(as.list(xs),function(v) is.numeric(v)&&length(v)==1L&&is.finite(v)&&v>0,TRUE)
      if(!length(xs)||length(xs)>100000L||!all(valid)) sc_fail("Se requiere un vector bootstrap finito y positivo.")
      att<-sc_number(p,"n_bootstrap_attempted",0,integer=TRUE)
      failed<-sc_number(p,"n_bootstrap_failed",0,closed_low=TRUE,integer=TRUE)
      if(failed!=0||att!=length(xs)) sc_fail("No se permite resumir remuestreos con fallos omitidos.")
      sc_text(p,"seed");fn<-sc_choice(p,"functional",c("mean","q50","q70","q90"));xs<-unlist(xs)
      A<-if(fn=="mean") mean(xs) else unname(quantile(xs,as.numeric(sub("q","",fn))/100,type=7))
      info<-list(functional=fn,quantile_definition="type7",bootstrap_count=att)
    }
  } else if(m=="M08.aipw_external") {
    n0<-sc_number(p,"n0",0,integer=TRUE);g<-sc_number(p,"gamma",0,1,closed_high=TRUE)
    A<-sc_number(p,"kappa2",0);B<-A/(g*n0);info$effective_external_controls<-g*n0
  } else if(m=="E01.cox_ate") {
    r<-sc_number(p,"r",0,1);phi<-sc_number(p,"phi",0,1,closed_high=TRUE)
    hr<-sc_number(p,"HR",0);d1<-sc_number(p,"d1",0,1,closed_high=TRUE);d0<-sc_number(p,"d0",0,1,closed_high=TRUE)
    if(isTRUE(p$censoring_double_counted)) sc_fail("La censura ya está incorporada en las probabilidades de evento.")
    if(phi==1) {i1<-1/r;i0<-1/(1-r)} else {
      pars<-sc_beta_parameters(r,phi);a<-pars$a;b<-pars$b
      if(a<=1||b<=1) sc_fail("Diverge un momento inverso de la propensión.","infinite_moment",a=a,b=b)
      i1<-(a+b-1)/(a-1);i0<-(a+b-1)/(b-1)
      info<-list(a=a,b=b,phi_residual=pars$phi_residual)
    }
    l1<-sqrt(r/(1-r))*sqrt(hr);l0<-1/l1;d<-r*d1+(1-r)*d0
    A<-(l1+l0)^2/d^2*(d1*r^2*l0^2*i1+d0*(1-r)^2*l1^2*i0)
    info$observed_event_probability<-d
  } else sc_fail("Procedimiento no implementado.","out_of_scope")
  sc_positive(A)
  if(!is.finite(B)||B<0) sc_fail("Componente de varianza no representable.","numeric_failure")
  list(A=unname(A),B=unname(B),info=info)
}
sc_normal_power <- function(A,B,n,delta,alpha,test,direction=1) {
  z<-qnorm(alpha/if(test=="two_sided") 2 else 1,lower.tail=FALSE)
  lambda<-(if(test=="two_sided") abs(delta) else direction*delta)/sqrt(A/n+B)
  pnorm(lambda-z)+if(test=="two_sided") pnorm(-lambda-z) else 0
}
sc_limit_power <- function(B,delta,alpha,test,direction) {
  if(B==0) return(if(delta!=0&&(test=="two_sided"||direction*delta>0)) 1 else if(delta==0) alpha else 0)
  sc_normal_power(0,B,1,delta,alpha,test,direction)
}
sc_integer_size <- function(A,B,delta,alpha,target,test,direction=1,mode="full_normal_integer") {
  if(delta==0) sc_fail("Un efecto nulo no alcanza la potencia solicitada.","unattainable",power_limit=alpha)
  if(test=="one_sided"&&direction*delta<=0) sc_fail("El efecto se opone a la dirección unilateral prevista.",field="direction")
  lim<-sc_limit_power(B,delta,alpha,test,direction)
  if(target>=lim) sc_fail("La potencia solicitada no es alcanzable.","unattainable",power_limit=lim,A=A,B=B)
  z<-qnorm(alpha/if(test=="two_sided") 2 else 1,lower.tail=FALSE)
  denom<-delta^2/(z+qnorm(target))^2-B
  raw<-if(denom>0) A/denom else NULL
  if(mode=="quantile_formula") {
    if(is.null(raw)) sc_fail("La aproximación de cuantiles no alcanza el objetivo.","unattainable",power_limit=lim,approximation=mode)
    if(raw>SC_MAX_N) sc_fail("La muestra supera el límite de cálculo.","computational_limit",max_n=SC_MAX_N,n_raw=raw)
    n<-max(1,ceiling(raw))
  } else {
    hi<-min(SC_MAX_N,max(2,if(!is.null(raw)&&is.finite(raw)) ceiling(raw) else SC_MAX_N))
    while(sc_normal_power(A,B,hi,delta,alpha,test,direction)<target) {
      if(hi==SC_MAX_N) sc_fail("La muestra supera el límite de cálculo.","computational_limit",max_n=SC_MAX_N,power_limit=lim)
      hi<-min(SC_MAX_N,hi*2)
    }
    lo<-1
    while(lo<hi) {
      mid<-floor((lo+hi)/2)
      if(sc_normal_power(A,B,mid,delta,alpha,test,direction)>=target) hi<-mid else lo<-mid+1
    }
    n<-lo
  }
  list(n=n,info=list(n_quantile_raw=raw,power_limit=lim,
                    power_at_previous_n=if(n>1) sc_normal_power(A,B,n-1,delta,alpha,test,direction) else NULL))
}
sc_precision_size <- function(A,B,confidence,h) {
  z<-qnorm((1-confidence)/2,lower.tail=FALSE);denom<-(h/z)^2-B
  if(denom<=0) sc_fail("La semianchura es inalcanzable con estos controles.","unattainable",half_width_limit=z*sqrt(B))
  raw<-A/denom
  if(raw>SC_MAX_N) sc_fail("La muestra supera el límite de cálculo.","computational_limit",max_n=SC_MAX_N,n_raw=raw)
  n<-max(1,ceiling(raw))
  while(z*sqrt(A/n+B)>h) {n<-n+1;if(n>SC_MAX_N) sc_fail("Límite computacional.","computational_limit")}
  while(n>1&&z*sqrt(A/(n-1)+B)<=h) n<-n-1
  list(n=n,info=list(half_width_achieved=z*sqrt(A/n+B),half_width_limit=z*sqrt(B)))
}
sc_detectable_effect <- function(p,research=FALSE) {
  alpha<-sc_number(p,"alpha",0,.5);target<-sc_number(p,"target_power",.5,1)
  n<-sc_number(p,"sample_size",0,SC_MAX_N,closed_high=TRUE,integer=TRUE)
  sign<-if(sc_choice(p,"direction",c("increase","decrease"))=="increase") 1 else -1
  test<-sc_choice(p,"test",c("two_sided","one_sided"));mode<-p$mode %||% "full_normal_integer"
  z<-qnorm(alpha/if(test=="two_sided") 2 else 1,lower.tail=FALSE)
  score<-function(A,B,delta) {
    if(mode=="quantile_formula") abs(delta)/sqrt(A/n+B)-(z+qnorm(target)) else
      sc_normal_power(A,B,n,delta,alpha,test,sign)-target
  }
  if(p$module_id=="M01.weights"&&p$outcome=="binary") {
    p0<-sc_number(p,"p0",0,1);r<-sc_number(p,"r",0,1)
    d0<-sc_number(p,"D0",1,closed_low=TRUE);d1<-sc_number(p,"D1",1,closed_low=TRUE)
    edge<-if(sign>0) 1-p0 else p0
    comp<-function(effect) {p1<-p0+sign*effect;d1*p1*(1-p1)/r+d0*p0*(1-p0)/(1-r)}
    if(score(comp(edge),0,sign*edge)<=0) sc_fail("No hay un riesgo interior que alcance esta potencia.","unattainable")
    magnitude<-uniroot(function(x) score(comp(x),0,sign*x),c(0,edge),tol=1e-14,check.conv=TRUE)$root
    delta<-sign*magnitude;p1<-p0+delta
    if(p1<=0||p1>=1) sc_fail("El efecto coincide con un límite binario no habilitado.","unattainable")
    v<-list(A=comp(magnitude),B=0,info=list(p1_detectable=p1))
  } else {
    v<-sc_variance(p,research);hi<-(z+qnorm(target))*sqrt(v$A/n+v$B)
    magnitude<-if(mode=="quantile_formula") hi else uniroot(function(x) score(v$A,v$B,sign*x),c(0,hi*1.01),tol=1e-14,check.conv=TRUE)$root
    delta<-sign*magnitude
  }
  v$delta<-delta;v
}
sc_required_design <- function(p) {
  m<-p$module_id;op<-p$calculation;params<-SC_MODULES[[m]]$variance_parameter_inputs
  if(!is.null(names(params))) {
    key<-if(p$outcome=="binary"&&op=="minimum_detectable_effect") "binary_MDE" else p$outcome
    params<-params[[key]]
  }
  required<-setdiff(unlist(params),c("estimand","scheme","homogeneous_effect","pilot_definition","q_definition",
                                   "effect_scale","functional","seed","resampling_metadata","pair_target_justification"))
  if(op %in% c("sample_size","power")&&m!="E01.cox_ate"&&!(m=="M01.weights"&&p$outcome=="binary"))
    required<-c(required,"delta")
  if(op %in% c("power","minimum_detectable_effect")) required<-c(required,"sample_size")
  if(is.numeric(p$loss)&&length(p$loss)==1&&is.finite(p$loss)&&p$loss!=0) required<-c(required,"loss")
  unique(required)
}
sc_metadata <- function(p,required) {
  sc_text(p,"scenario_name")
  if(!isTRUE(p$assumptions_confirmed)) sc_fail("Confirma que el diseño y los supuestos corresponden al estudio.",field="assumptions_confirmed")
  if(p$module_id!="M05.summary") sc_text(p,"effect_units")
  if(!is.list(p$provenance)) sc_fail("Falta la procedencia de los parámetros.",field="provenance")
  for(key in required) {
    item<-p$provenance[[key]]
    if(!is.list(item)||!sc_member(item$kind,SC_KINDS)||!is.character(item$detail)||
       length(item$detail)!=1L||is.na(item$detail)||!nzchar(trimws(item$detail)))
      sc_fail(paste("Documenta la procedencia de",SC_PRESENTATION$labels[[key]] %||% key),field=paste0("provenance.",key))
  }
}
sc_calculate_impl <- function(p,research=FALSE,require_metadata=TRUE) {
  if(!is.list(p)||is.null(names(p))) sc_fail("La solicitud debe ser un objeto.")
  m<-p$module_id
  if(!sc_member(m,names(SC_MODULES))) sc_fail("Procedimiento fuera de alcance.","out_of_scope")
  module<-SC_MODULES[[m]]
  if(!m %in% SC_PUBLIC&&!research) sc_fail("El procedimiento experimental está desactivado.","disabled_variant")
  if(m=="M02.table"&&sc_member(p$estimand,c("MW","EW"))&&!research)
    sc_fail("Matching weights y entropía están reservados para verificación interna.","disabled_variant")
  op<-sc_choice(p,"calculation",module$functions)
  if(!sc_member(p$outcome,module$outcomes)) sc_fail("Desenlace no habilitado.","out_of_scope")
  if(!sc_member(p$estimand,module$estimands)&&!(research&&m=="M02.table"&&sc_member(p$estimand,c("MW","EW"))))
    sc_fail("Estimando no habilitado.","out_of_scope")
  if(require_metadata) sc_metadata(p,sc_required_design(p))
  limitations<-c(unlist(SC_PRESENTATION$limitations[[m]]),"Prototipo con verificación numérica. Calibración estadística y evaluación con usuarios pendientes.")
  result<-list(status="ok",software_version=SC_VERSION,implementation="R",contract_version=SC_CONTRACT$version,
    generated_at=format(Sys.time(),"%Y-%m-%dT%H:%M:%OS6Z",tz="UTC"),module_id=m,method=SC_PRESENTATION$names[[m]],
    source_id=module$source,source=SC_CONTRACT$sources[[module$source]],estimand=p$estimand,outcome=p$outcome,
    calculation=op,calculation_mode=p$mode %||% "full_normal_integer",inputs=p,provenance=p$provenance %||% list(),
    assumptions_confirmed=p$assumptions_confirmed %||% FALSE,n_meaning=module$n_means,limitations=as.list(limitations),
    research_only=!m %in% SC_PUBLIC||(m=="M02.table"&&sc_member(p$estimand,c("MW","EW"))),
    all_inputs=p,effect_scale=p$effect_units,active_restrictions=as.list(limitations))
  result$source_version<-result$source$version %||% "see frozen contract"
  if(m=="M05.summary") {
    nc<-sc_number(p,"n_control",0,integer=TRUE);ni<-sc_number(p,"n_treated_interim",0,integer=TRUE)
    rate<-sc_number(p,"mean_resampling_match_rate",0,1,closed_high=TRUE);aci<-sc_number(p,"alpha_ci",0,.5)
    sc_text(p,"pair_target_justification");sc_text(p,"resampling_metadata")
    if(ni>nc) sc_fail("Los tratados intermedios no pueden superar los controles.",field="n_treated_interim")
    lower<-rate-qnorm(aci,lower.tail=FALSE)*sqrt(rate*(1-rate)/nc)
    if(lower<=0) sc_fail("El límite de emparejamiento no es positivo.","unattainable",lower_match_rate=lower)
    total<-max(ni,ceiling(nc/lower))
    if(total>SC_MAX_N) sc_fail("El reclutamiento supera el límite.","computational_limit",max_n=SC_MAX_N)
    result$n_treated_final<-total;result$n_additional<-max(0,total-ni);result$intermediates<-list(lower_match_rate=lower)
    result$calculation_mode<-"published_resampling_summary";return(result)
  }
  mode<-if(!is.null(p$mode)) sc_choice(p,"mode",c("full_normal_integer","quantile_formula")) else "full_normal_integer"
  loss<-if(!is.null(p$loss)) sc_number(p,"loss",0,1,closed_low=TRUE) else 0
  if(op!="precision") {
    alpha<-sc_number(p,"alpha",0,.5);test<-sc_choice(p,"test",c("two_sided","one_sided"));direction<-1
    if(test=="one_sided"||op=="minimum_detectable_effect")
      direction<-if(sc_choice(p,"direction",c("increase","decrease"))=="increase") 1 else -1
  }
  if(op=="minimum_detectable_effect") {
    v<-sc_detectable_effect(p,research);delta<-v$delta;n<-p$sample_size;result$minimum_detectable_effect<-delta
  } else {
    v<-sc_variance(p,research);delta<-NULL
    if(op!="precision") {
      if(m=="M01.weights"&&p$outcome=="binary") {
        delta<-p$p1-p$p0
        if(!is.null(p$delta)&&abs(sc_number(p,"delta")-delta)>1e-12) sc_fail("El efecto debe ser p1 menos p0.",field="delta")
      } else if(m=="E01.cox_ate") delta<-log(p$HR) else delta<-sc_number(p,"delta")
    }
    if(op=="sample_size") {
      target<-sc_number(p,"target_power",.5,1)
      size<-sc_integer_size(v$A,v$B,delta,alpha,target,test,direction,mode);n<-size$n;v$info<-c(v$info,size$info)
    } else if(op=="precision") {
      conf<-sc_number(p,"confidence",.5,1);h<-sc_number(p,"half_width",0)
      size<-sc_precision_size(v$A,v$B,conf,h);n<-size$n;v$info<-c(v$info,size$info);result$calculation_mode<-"normal_interval"
    } else n<-sc_number(p,"sample_size",0,SC_MAX_N,closed_high=TRUE,integer=TRUE)
  }
  result$n_analyzable<-n;result$n_recruit_expected<-ceiling(n/(1-loss))
  result$intermediates<-c(v$info,list(A=v$A,B=v$B));result$variance_at_n<-v$A/n+v$B
  if(!is.null(delta)) {
    result$effect<-delta;result$power_recalculated<-sc_normal_power(v$A,v$B,n,delta,alpha,test,direction)
    result$power_limit<-sc_limit_power(v$B,delta,alpha,test,direction)
  }
  if(!is.null(p$r)) result$expected_group_counts<-list(treated=n*p$r,control=n*(1-p$r))
  if(m %in% c("M06.prediction","M08.aipw_external")) result$n_external_fixed<-p$n0
  result
}
sc_justification <- function(r) {
  if(r$status!="ok") return(r$message)
  p<-r$inputs
  body<-switch(r$calculation,
    recruitment_reestimation=sprintf("Se estiman %.0f tratados totales y %.0f adicionales; límite inferior de emparejamiento %.6g.",r$n_treated_final,r$n_additional,r$intermediates$lower_match_rate),
    minimum_detectable_effect=sprintf("Con n=%.0f, efecto mínimo detectable %.8g %s; potencia normal %.6g.",r$n_analyzable,r$minimum_detectable_effect,p$effect_units,r$power_recalculated),
    precision=sprintf("Se requieren %.0f observaciones analizables para semianchura %g y confianza %g.",r$n_analyzable,p$half_width,p$confidence),
    sprintf("El cálculo corresponde a %.0f %s; potencia normal %.6g.",r$n_analyzable,
            if(r$n_meaning=="new_treated") "tratados nuevos" else "participantes en total",r$power_recalculated))
  numeric_keys<-names(p)[vapply(p,function(x) is.numeric(x)&&length(x)==1,TRUE)]
  params<-paste(vapply(numeric_keys,function(k) paste0(SC_PRESENTATION$labels[[k]] %||% k,"=",format(p[[k]],digits=10)), ""),collapse="; ")
  paste(paste0(p$scenario_name,"."),"Se utilizó",r$method,paste0("(SampleCausal R ",SC_VERSION,"),"),"para",paste0(r$estimand,"."),
        body,"Parámetros:",paste0(params,"."),"Modo:",paste0(r$calculation_mode,"."),"Fuente:",r$source$url,paste(unlist(r$limitations),collapse=" "))
}
sc_finite_result <- function(x) {
  if(is.numeric(x)) return(all(is.finite(x)))
  if(is.list(x)) return(all(vapply(x,sc_finite_result,TRUE)))
  TRUE
}
sc_calculate <- function(payload,research=FALSE,require_metadata=TRUE) {
  tryCatch({
    r<-sc_calculate_impl(payload,research,require_metadata)
    if(!sc_finite_result(r)) sc_fail("El resultado excede la representación numérica.","numeric_failure")
    r$justification<-sc_justification(r);r
  },sc_error=function(e) list(status=e$status,message=e$message,details=e$details,software_version=SC_VERSION),
    error=function(e) list(status="numeric_failure",message="El cálculo no alcanzó la precisión o convergencia requerida.",software_version=SC_VERSION))
}
sc_sensitivity <- function(payload,parameter,values) {
  allowed<-c("r","D0","D1","p0","p1","sd0","sd1","sd_common","delta","phi","rho2","S","n0","p","residual_var0","residual_var1")
  if(!is.list(payload)||!sc_member(parameter,allowed)||is.null(payload[[parameter]]))
    return(list(status="invalid_input",message="El parámetro no pertenece al escenario actual."))
  if(!(is.list(values)||is.numeric(values))||!length(values)||length(values)>5)
    return(list(status="invalid_input",message="Introduce entre uno y cinco valores."))
  rows<-lapply(values,function(value) {
    p<-payload;p[[parameter]]<-value
    p$provenance[[parameter]]<-list(kind="sensitivity_scenario",detail=paste("Sensibilidad explícita de",parameter,"; base:",p$scenario_name))
    list(value=value,result=sc_calculate(p))
  })
  list(status="ok",software_version=SC_VERSION,base_scenario=payload,parameter=parameter,rows=rows,
       note="Escenarios del mismo procedimiento y estimando. No se elige automáticamente la menor muestra.")
}
