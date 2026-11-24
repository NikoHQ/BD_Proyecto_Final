<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/api.php';
require_once __DIR__ . '/../includes/catalogo-dto.php';

/**
 * Catalogo del portal: el cliente necesita canchas y horarios para buscar.
 *
 *   GET catalogo.php
 */

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    apiFail('Metodo no permitido.', 405);
}
apiSesion(['CLIENTE']);

try {
    apiOk(catalogoPanel());
} catch (Throwable $error) {
    error_log('SGCD catalogo portal: ' . $error->getMessage());
    apiFail('No se pudo leer el catalogo del recinto.', 503);
}
