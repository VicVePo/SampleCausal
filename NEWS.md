# SampleCausal 1.0.2

- Valida las carpetas de exportación al construir la aplicación: crea el directorio si hace falta y exige una ruta absoluta verificable antes de iniciar el servidor.
- La versión anterior admitía un archivo existente como destino y fallaba al intentar guardar. Ahora rechaza ese destino de inmediato y conserva intacto el archivo.
- Fija las rutas relativas existentes y nuevas antes de cambiar el directorio de trabajo. Esto evita depender del comportamiento específico de cada sistema al normalizar rutas inexistentes; el cambio de directorio ya funcionaba en el Windows evaluado.
- Ocho comprobaciones de regresión adicionales, incluido guardado real mediante el servidor Shiny después de cambiar el directorio de trabajo.
- La interfaz y la documentación distinguen la versión del paquete 1.0.2 de la versión del motor 1.0.1. Los 25 recursos congelados del motor y sus resultados permanecen idénticos.

# SampleCausal 1.0.1

- Primera distribución como paquete R instalable, basada en el motor validado 1.0.1.
- Funciones públicas para cálculo, catálogo de métodos y ejemplos, sensibilidad, exportación y reproducción histórica.
- Interfaz Shiny incluida; recursos localizados desde la instalación y exportaciones fuera de ella.
- Ayuda de las funciones, guía ejecutable, cita del software y licencia MIT.
- Pruebas de integración y comprobación de identidad de las fuentes del motor.
- Se conservan las fórmulas, restricciones y enmienda M06–E1. El empaquetado no constituye una nueva versión matemática del motor.
