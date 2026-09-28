# Enmienda prospectiva de cierre — E1 (28 septiembre 2026)
Estado al congelar: no se han generado resultados de E1. La auditoría anterior motivó esta extensión; no es parte del protocolo original y no se combinarán sus réplicas con las originales.

## Decisión científica
M06 mantendrá el estimador predictivo OLS de Erdmann et al., la prueba normal y el intervalo bilateral normal. Se corrige exclusivamente la esperanza de su varianza para p covariables SIN intercepto:
A = v1 + v0*p/(n0-p-2), B = v0/n0 + v0*p/[n0*(n0-p-2)].
Para p=0: A=v1, B=v0/n0. Las funciones de potencia, tamaño, precisión y efecto mínimo siguen siendo aproximaciones normales; no potencia exacta ni garantía condicional a una base histórica fija.
La fórmula n0-p-1 se conserva en motores históricos y como variante explícita de reproducción interna. No se atribuye a los autores una corrección o fe de erratas inexistente.

## Dominio operativo decidido antes de E1
La entrega pública M06 requerirá al menos 100 grados de libertad residuales en ambas regresiones (n0-p-1>=100 y n1-p-1>=100). Es una restricción operativa conservadora de esta entrega; no es un teorema ni un mínimo universal. Los mínimos estructurales anteriores se preservan y ningún tamaño se aumentará silenciosamente. Si la fórmula produce un n inferior, la aplicación comunicará que queda fuera del dominio operativo y permitirá estudiar una muestra especificada mediante la operación potencia.
La corrección matemática se implementará para todo su dominio finito en investigación. La evaluación cubre la cuadrícula indicada, no todas las combinaciones continuas admitidas por la fórmula. No habrá promesa de validación universal.

## Cuadrícula principal
Producto cartesiano p={0,1,5,20,100}, df0={100,250,750}, df1={100,250,750}, v0/v1={0.25,1,4}, v1=1: 135 geometrías. n_j=df_j+p+1. Mismas covariables gaussianas iid en las dos poblaciones, intercepto, efectos constantes y errores gaussianos independientes homocedásticos dentro de cada población.
Por geometría: 100000 réplicas del vector de estadísticos suficiente; cada réplica se analiza bajo delta=0 y bajo dos alternativas elegidas determinísticamente mediante la potencia normal de la varianza media (objetivos .80 y .90). Pruebas unilateral alfa=.025 y bilateral alfa=.05; IC bilateral95% en ambas. Se permiten números aleatorios comunes entre hipótesis, se informa esta dependencia y nunca se suman como muestras independientes.
Alternativas: delta=(qnorm(.975)+qnorm(objetivo))*sqrt(E[V]); para bilateral se verificará la mínima diferencia de la cola opuesta mediante cálculo determinista. Se informará potencia nominal completa.
Anclajes adicionales originales: (n0,p,n1,delta)=(750,5,140,.3),(1000,5,885,.15). Ocho geometrías de tensión con pocos grados de libertad, fuera del dominio operativo; entre ellas (8,5,23,2.5), detectada en la auditoría anterior. No se seleccionarán retrospectivamente escenarios favorables.

## Reducción exacta del generador gaussiano
L=1/n0+(1/n0+1/n1)*p/(n0-p)*F[p,n0-p] para p>0, y L=1/n0 para p=0.
V=v1/n1+v0*L; theta=delta+sqrt(V)*Z;
s0²=v0*chi²[df0]/df0, s1²=v1*chi²[df1]/df1; SE²=s1²/n1+s0²*L.
F, Z y las dos chi-cuadradas son independientes. Esto reproduce la distribución conjunta del estimador y su varianza estimada del análisis OLS bajo el modelo; NO simula diseños con mala especificación, cambios de población ni una historia fija. Se conserva el código de la derivación y un contraste independiente por generación de matrices y ajustes OLS completos.
La reducción sigue de d~N(0,(1/n0+1/n1)Sigma), independiente del scatter S~Wishart(Sigma,n0-1), y la distribución de d'S^-1d. E[L]=1/n0+(1/n0+1/n1)*p/(n0-p-2).
Fuentes: Erdmann et al. https://doi.org/10.1002/bimj.202200023 ; momento inverso Wishart https://jbds.isdsa.org/public/journals/1/html/v1n2/p2/ . La reducción y la corrección aquí indicadas son nuestra derivación, no texto atribuido a esas publicaciones.

## Criterios y contingencia
Wilson95% por celda, sin garantía simultánea. Márgenes del protocolo original: tipo I alfa±.01, potencia objetivo±.03, cobertura .95±.02. Se informan denominadores, errores Monte Carlo y fallos (no se omiten).
Para habilitar M06 con esta restricción operativa: todas las celdas principales deben quedar dentro de sus márgenes para tipo I, potencia y cobertura. Si alguna falla o es inconclusa se retira M06 de la entrega pública de cierre; no se retoca el margen, el umbral o el número de réplicas para obtener aprobación. Los anclajes y tensiones son caracterización adicional.
100000 réplicas fijas por geometría. Sin detención opcional. Semilla maestra L'Ecuyer-CMRG 2026092802; un stream por geometría; streams independientes adicionales para contrastes OLS. Evidencia guardada: plan y hash antes de ejecución, streams, código congelado, conteos, momentos, cuantiles, intervalos, decisiones y sesión. Se conservan resúmenes suficientes y RNG para regenerar cada réplica; no se guardan millones de filas redundantes.
Contraste OLS: 12 geometrías preseleccionadas en el código, 2000 matrices por geometría salvo p=100 (300). Se comprueba coincidencia algebraica entre dos cálculos de SE; tasas y CDF de L se contrastan con margen de 5 errores estándar Monte Carlo combinados más 1/R. Se informan todos los contrastes. Si falla, investigar el generador antes de usar E1 como evidencia.

## Entregables de cierre
Motor y servidor coherentes, enmienda visible en salida/JSON/texto/sensibilidad, reproducción exacta de versiones 0.4.0–0.4.3, pruebas de regresión y fronteras, extensión E1 concluida y reporte definitivo. Distribución local R/Shiny con instalación de dependencias, ejecución y reproducción documentadas. Fase5 con participantes y publicación pública posteriores; ninguna se simula mediante pruebas automáticas.

