# Publicación de la entrega preparada

El paquete debe publicarse desde la raíz que contiene DESCRIPTION, NAMESPACE, R/, man/ e inst/. El repositorio público previsto es VicVePo/SampleCausal; su creación y publicación no se dan por realizadas.

1. Confirmar que los archivos de distribución coinciden con el recibo de la entrega y que R CMD check y la instalación desde los archivos fueron satisfactorios.
2. Crear el repositorio GitHub y subir este contenido, excluyendo bibliotecas locales, archivos temporales, exportaciones de usuarios y material de entrevistas retirado del estudio.
3. Ejecutar el flujo R-CMD-check en los tres sistemas. Los resultados remotos permanecen pendientes hasta su ejecución efectiva.
4. Crear la etiqueta v1.0.2 y una versión de GitHub con el archivo fuente, el binario Windows y sus hashes. Actualizar README y DESCRIPTION con enlaces públicos verificados.
5. Verificar la instalación remota en una biblioteca independiente antes de anunciar que install_github está disponible.

La publicación es una acción posterior sobre GitHub. Este archivo no concede autorización adicional ni certifica que se haya efectuado.
