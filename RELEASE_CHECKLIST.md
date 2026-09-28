# Publicación de la entrega preparada

El paquete se distribuye desde la raíz que contiene DESCRIPTION, NAMESPACE, R/, man/ e inst/. Repositorio público: https://github.com/VicVePo/SampleCausal. Esta lista describe el procedimiento de publicación; por sí sola no certifica la ejecución de todos sus pasos.

1. Confirmar que los archivos de distribución coinciden con el recibo de la entrega y que R CMD check y la instalación desde los archivos fueron satisfactorios.
2. Subir este contenido al repositorio GitHub, excluyendo bibliotecas locales, archivos temporales, exportaciones de usuarios y material de entrevistas retirado del estudio.
3. Ejecutar el flujo R-CMD-check en los tres sistemas. Los resultados remotos permanecen pendientes hasta su ejecución efectiva.
4. Crear la etiqueta v1.0.2 y una versión de GitHub con el archivo fuente, el binario Windows y sus hashes. Actualizar README y DESCRIPTION con enlaces públicos verificados.
5. Verificar la instalación remota en una biblioteca independiente antes de anunciar que install_github está disponible.

Verificar el resultado mediante la versión pública, el commit de la etiqueta, los registros del flujo de comprobación y los hashes de los archivos descargados.
