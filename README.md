# SampleCausal

Paquete R para planificar el tamaño muestral, la potencia, la precisión y el efecto mínimo detectable con métodos seleccionados de inferencia causal. Incluye funciones utilizables directamente desde R y una interfaz Shiny local. Versión del paquete: **1.0.2**; motor matemático conservado: **1.0.1**.

## Instalar la entrega local

Instalar primero las dependencias de ejecución, si no están disponibles:

```r
install.packages(c("jsonlite", "shiny"))
```

En Windows, seleccionar `SampleCausal_1.0.2.zip`:

```r
install.packages(file.choose(), repos = NULL, type = "win.binary")
```

Para instalar el código fuente en Windows, Linux o macOS, seleccionar `SampleCausal_1.0.2.tar.gz`:

```r
install.packages(file.choose(), repos = NULL, type = "source")
```

El paquete no contiene código C/C++ que deba compilarse. La instalación y las pruebas se verificaron en Windows con R 4.6.1; la comprobación en otros sistemas está preparada en el flujo de GitHub, pero no se declara ejecutada.

El repositorio público todavía no se ha publicado. Cuando exista `VicVePo/SampleCausal`, la ruta prevista será `remotes::install_github("VicVePo/SampleCausal")`; esa orden no se presenta como disponible antes de la publicación. No es necesario publicarlo en CRAN para distribuirlo desde GitHub.

## Calcular desde R

```r
library(SampleCausal)

escenario <- causal_example("T1")
resultado <- causal_calculate(escenario)
resultado$status             # "ok"
resultado$n_analyzable       # 1035
resultado$power_recalculated # aproximadamente 0.800098
```

Todos los ejemplos son ficticios. Para un estudio propio, se deben especificar el método, el estimando, los supuestos y la procedencia de los valores. Cambiar un parámetro exige revisar también su justificación; copiar un ejemplo no acredita los supuestos de otro estudio.

```r
causal_methods()
causal_examples()
causal_methods(details = TRUE)[["M06.prediction"]]
help("causal_calculate", package = "SampleCausal")
vignette("uso", package = "SampleCausal")
```

La operación se indica en `escenario$calculation`: `sample_size`, `power`, `precision`, `minimum_detectable_effect` o `recruitment_reestimation`, según el método. La ayuda y la guía explican sus entradas. Siempre se debe comprobar `status` antes de utilizar una cifra.

## Abrir la calculadora gráfica

```r
run_samplecausal()
```

La aplicación se abre en el navegador del equipo. Para detenerla, interrumpir la ejecución de R. Las copias de exportación se guardan por defecto en una carpeta temporal de la sesión; los botones de descarga permiten conservarlas. Para elegir un destino persistente:

```r
run_samplecausal(export_dir = file.path(path.expand("~"), "SampleCausal-exports"))
```

`samplecausal_app()` permite obtener el objeto Shiny sin iniciar el servidor. La carpeta de exportación se crea al construir la aplicación y queda registrada con su ruta absoluta: cambiar después el directorio de trabajo de R no cambia el destino. Los destinos predeterminados están fuera de la instalación del paquete.

## Sensibilidad, exportación y reproducción

```r
comparacion <- causal_sensitivity(causal_example("T3"), "delta", c(0.03, 0.2, 0.3))
comparacion$rows[[1]]$result$status # "unattainable"

archivos <- causal_export(resultado, file.path(tempdir(), "mi-calculo"))
recalculado <- causal_replay(archivos$saved_json)
recalculado$n_analyzable
```

La sensibilidad conserva los escenarios rechazados. La reproducción de versiones históricas utiliza el motor correspondiente y mantiene sus textos y fórmulas; no rehabilita recomendaciones retiradas. Los rechazos sin entradas propias se reproducen desde su escenario original, no desde un registro incompleto. El campo `software_version` de los resultados identifica el motor matemático 1.0.1; la versión del paquete instalado se consulta con `packageVersion("SampleCausal")` y es 1.0.2. Esta revisión corrige la validación del destino de exportación, sin cambiar los resultados del motor.

## Métodos y límites

| Método | Alcance público |
|---|---|
| M01.weights | ATE continuo o binario mediante efectos de diseño de los pesos |
| M01.adjusted_variance | ATE continuo con varianzas ajustadas y definición documentada |
| M02.table | ATE y ATO continuos en la cuadrícula tabulada; ATT retirado |
| M03.normal | ATE, ATT, ATC y ATO continuos bajo los supuestos del método |
| M06.prediction | Controles externos con modelo lineal y enmienda local M06–E1 |
| M05.summary | Reestimación del reclutamiento con resúmenes de emparejamiento |

M06–E1 conserva la aproximación normal basada en la varianza media, con denominador `n0-p-2` para `p>0` y al menos 100 grados de libertad residuales por grupo. Es una modificación matemática local declarada, no una corrección publicada por los autores originales. La evidencia de simulación es específica de los modelos evaluados. M02–ATT sigue retirado, los resultados inconclusos siguen siendo inconclusos y los módulos experimentales permanecen deshabilitados en el uso público. M01 ajustado y M05 tienen verificación matemática y funcional sin atribuirles una simulación propia completa.

La evaluación del software emplea escenarios ficticios, referencias matemáticas y simulaciones. No incluye entrevistas ni participantes. Las pruebas de empaquetado comprueban que la instalación conserva el motor y sus resultados; no constituyen una nueva calibración estadística.

## Documentación, licencia y mantenimiento

Autor y mantenedor: Victor J. Vera-Ponce, victor_jvp@hotmail.com. Licencia MIT. La cita del software está disponible mediante `citation("SampleCausal")`. Las referencias de cada método se encuentran en `causal_methods(details = TRUE)` y en los resultados.

La estructura y comprobación del paquete siguen el manual oficial [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html). La interfaz utiliza el mecanismo documentado de [aplicaciones Shiny](https://shiny.posit.co/r/reference/shiny/latest/runapp.html) y [recursos estáticos para paquetes](https://shiny.posit.co/r/reference/shiny/latest/resourcepaths.html).
