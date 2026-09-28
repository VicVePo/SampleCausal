# Independent mathematics: no production helpers, engine imports, or saved expected constants.
# The argument observed is the CURRENT motor output; the original audit also checked the frozen baseline.
f5_independent<-function(inputs,observed) {
near<-function(x,y,tol=1e-10) length(x)==1 && is.finite(x) && abs(x-y)<=tol*max(1,abs(y))
pow<-function(n,A,B=0,p) {
  z<-qnorm(1-p$alpha/if(p$test=="two_sided")2 else 1)
  mu<-abs(p$delta)/sqrt(A/n+B)
  if(p$test=="two_sided") pnorm(mu-z)+pnorm(-mu-z) else pnorm(mu-z)
}
# Exhaustive integer search (no production inversion or implementation import).
solve_n<-function(A,B,p) {
  candidates<-seq_len(100000)
  which(pow(candidates,A,B,p)>=p$target_power)[1]
}
binaryA<-function(p) p$D1*p$p1*(1-p$p1)/p$r+p$D0*p$p0*(1-p$p0)/(1-p$r)
e1<-function(p) {
 t<-p$p/(p$n0-p$p-2)
 c(A=p$residual_var1+p$residual_var0*t,B=p$residual_var0*(1+t)/p$n0)
}
# T2: independent bisection on beta concentration; literal general C_z,D_z
# expression from the saved phase-2 contract, integrated by composite Simpson.
# The production code uses adaptive quadrature and a simplified ATO expression.
ato<-function(p,segments) {
  overlap<-function(k) {
    a<-k*p$r;b<-k*(1-p$r)
    exp(lgamma(a+.5)-lgamma(a)-.5*log(a)+lgamma(b+.5)-lgamma(b)-.5*log(b))
  }
  lo<-0.001;hi<-100
  for(j in seq_len(100)) {mid<-(lo+hi)/2;if(overlap(mid)<p$phi)lo<-mid else hi<-mid}
  k<-(lo+hi)/2;a<-k*p$r;b<-k*(1-p$r)
  mu<-digamma(a)-digamma(b);s2<-trigamma(a)+trigamma(b)
  z<-seq(-12,12,length.out=segments+1);w<-mu+sqrt(s2)*z
  weights<-c(1,rep(c(4,2),segments/2)[seq_len(segments-1)],1)
  simpson<-function(y) sum(y*dnorm(z)*weights)*(24/segments)/3
  e<-plogis(w);ec<-plogis(-w);h<-e*ec
  H<-simpson(h);center<-simpson(w*h)/H
  D1<-simpson(h*h/e);D0<-simpson(h*h/ec)
  C1<-simpson((w-center)^2*h*h/e);C0<-simpson((w-center)^2*h*h/ec)
  A<-p$S^2*(p$rho2*(C1+C0)/s2+(1-p$rho2)*(D1+D0))/H^2
  list(A=A,a=a,b=b,mu=mu,sigma2=s2,H=H,center=center,segments=segments,normal_tail_mass=2*pnorm(-12))
}
A1<-binaryA(inputs$T1);A6<-binaryA(inputs$T6B)
v3<-e1(inputs$T3);v4<-e1(inputs$T4)
m2a<-ato(inputs$T2,10000);m2b<-ato(inputs$T2,20000)
vals<-list(T1=list(A=A1,B=0),T2=list(A=m2b$A,B=0),T3=as.list(v3),T6B=list(A=A6,B=0))
rows<-lapply(names(vals),function(id) {
 p<-inputs[[id]];v<-vals[[id]];n<-solve_n(v$A,v$B,p)
 actual<-observed[[id]]
 data.frame(id=id,A=v$A,B=v$B,n=n,power=pow(n,v$A,v$B,p),previous_power=pow(n-1,v$A,v$B,p),
  A_ok=near(actual$intermediates$A,v$A),B_ok=near(actual$intermediates$B,v$B),
  n_ok=identical(as.numeric(actual$n_analyzable),as.numeric(n)),
  power_ok=near(actual$power_recalculated,pow(n,v$A,v$B,p)),
  minimal=pow(n,v$A,v$B,p)>=p$target_power && pow(n-1,v$A,v$B,p)<p$target_power)
})
table<-do.call(rbind,rows)
p4<-inputs$T4;lim4<-pnorm(abs(p4$delta)/sqrt(v4["B"])-qnorm(1-p4$alpha))
checks4<-list(status=identical(observed$T4$status,"unattainable"),
 power_limit=near(observed$T4$details$power_limit,lim4),
 A=near(observed$T4$details$A,v4["A"]),B=near(observed$T4$details$B,v4["B"]),
 no_finite_sample_size=is.null(observed$T4$n_analyzable),
 target_unattainable=lim4<p4$target_power)
p5<-inputs$T5
lower5<-p5$mean_resampling_match_rate-qnorm(1-p5$alpha_ci)*sqrt(p5$mean_resampling_match_rate*(1-p5$mean_resampling_match_rate)/p5$n_control)
n5<-ceiling(p5$n_control/lower5)
checks5<-list(total=observed$T5$n_treated_final==n5,
 additional=observed$T5$n_additional==n5-p5$n_treated_interim)
checks6a<-list(status=identical(observed$T6A$status,"disabled_variant"),
 no_finite_sample_size=is.null(observed$T6A$n_analyzable),
 input_still_ATT=identical(inputs$T6A$estimand,"ATT"))
all_ok<-all(unlist(table[,c("A_ok","B_ok","n_ok","power_ok","minimal")])) &&
 all(unlist(checks4)) && all(unlist(checks5)) && all(unlist(checks6a)) && near(m2a$A,m2b$A)

 stopifnot(all_ok)
 list(all_passed=all_ok,solved=table,T2=list(coarse=m2a,fine=m2b,difference=abs(m2a$A-m2b$A)),
 T4=list(A=unname(v4["A"]),B=unname(v4["B"]),power_limit=unname(lim4),checks=checks4),
 T5=list(lower=lower5,total=n5,additional=n5-p5$n_treated_interim,checks=checks5),T6A=checks6a)
}
