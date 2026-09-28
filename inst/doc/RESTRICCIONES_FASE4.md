# Restricciones vigentes — versión 1.0.0

El informe de cierre y la enmienda E1 resuelven el pendiente matemático de M06. No debe interpretarse esta entrega como validación universal.

| Ruta | Restricción vigente |
|---|---|
| Cohortes M01–M03 | n total >=2; es un mínimo estructural, no garantía de observación de ambos grupos o estimabilidad. Supuestos específicos de cada fuente obligatorios. |
| M01 ajustada | Definición exacta de varianza de la sección6; verificación matemática sin anclaje empírico propio. |
| M02 | ATT, MW y EW excluidos de la interfaz pública. ATE y ATO mantienen resultados originales inconclusos. AUC y proporción deben pertenecer al dominio tabulado. |
| M03 | Efecto homogéneo y aproximación normal del índice. ATO compatible en el anclaje original; los demás anclajes conservan su incertidumbre. |
| M06-E1 | p excluye intercepto. n0-p-2 en varianza media; p=0 separado. n0-p-1 y n1-p-1 >=100 en la entrega pública; no se aumenta n automáticamente. Normalidad, distribuciones comparables, modelo correcto y errores independientes. |
| M05 | Solo resúmenes de remuestreo documentados; no realiza matching ni demuestra validez de un algoritmo. |
| M07/M08/E01 | Fuera de la entrega pública; preservados para reproducción interna. |

En M06, E1 evaluó p=0,1,5,20,100; grados residuales=100,250,750; razones de varianza=.25,1,4; alfa .025 unilateral/.05 bilateral y potencia .80/.90. La compatibilidad de la cuadrícula no demuestra validez para cualquier parámetro entre o fuera de esos valores. La restricción de 100 grados es operativa, no universal. No hay garantía condicional a una historia externa fija.

Potencia y semianchura son aproximaciones del modelo; no constituyen garantías empíricas individuales. La precisión no expresa la probabilidad de alcanzar una anchura. Los resultados originales no se reclasificaron con E1.

Los motores históricos preservan la fórmula n0-p-1. Las exportaciones actuales incluyen software1.0.0, contrato2.2 y enmiendaE1. La interfaz no acepta un indicador que permita saltarse estas restricciones.

El detalle vigente se encuentra en [CIERRE_FASES3Y4.md](CIERRE_FASES3Y4.md) y [ENMIENDA_E1.md](ENMIENDA_E1.md).
