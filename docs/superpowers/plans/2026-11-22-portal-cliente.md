# Portal de clientes

Construir la demo de reservas bajo `web/cliente/` con Bootstrap, vistas PHP y un servicio de demostración aislado. La interfaz utilizará estados de negocio, no detalles de Oracle. Las referencias definen el aspecto general y el flujo acordado define las operaciones.

- [x] Crear pruebas del servicio de disponibilidad, cálculo por franjas, permisos y transiciones. Ejecutar `php tests/portal-cliente.php`.
- [x] Implementar el servicio y datos de prueba. Mantener sesión, selección y reservas de demo independientes del panel del personal.
- [x] Implementar el recorrido desde modalidad hasta comprobante y después el historial, detalle, cancelación y cuenta. Mantener formularios compatibles con teclado y navegación móvil.
- [x] Verificar en navegador el recorrido y la presentación móvil. Verificar por HTTP los errores recuperables y el funcionamiento con una cuenta sin verificar.
- [x] Documentar cómo probar el portal local y el contrato para su conexión futura a PHP y Oracle.

Puntos de revisión: no mostrar datos de otros clientes, conservar el borrador durante el acceso, revalidar precio y disponibilidad, garantizar un solo resultado por solicitud y actualizar disponibilidad al cancelar.
