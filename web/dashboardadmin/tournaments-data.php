<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/tournament-store.php';

authStart();
requireStaff();
header('Content-Type: application/json; charset=utf-8');

$store = new TournamentStore();
try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $token = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
        if (!isset($_SESSION['csrf']) || !hash_equals($_SESSION['csrf'], $token)) {
            http_response_code(403);
            echo json_encode(['message' => 'La sesión del formulario venció. Vuelve a cargar la página.']);
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true, flags: JSON_THROW_ON_ERROR);
        if (!is_array($input)) throw new InvalidArgumentException('Datos inválidos.');
        $response = $store->replaceAdminSnapshot($input, ($input['importLegacy'] ?? null) === true);
    } else {
        $response = $store->adminSnapshot();
    }
    echo json_encode($response, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
} catch (TournamentRule $error) {
    http_response_code($error->reason === 'STALE' ? 409 : 422);
    echo json_encode(['reason' => $error->reason, 'message' => $error->getMessage()]);
} catch (JsonException|TypeError|InvalidArgumentException) {
    http_response_code(400);
    echo json_encode(['message' => 'Los datos enviados no tienen el formato esperado.']);
} catch (Throwable $error) {
    error_log('SGCD torneos: ' . $error->getMessage());
    http_response_code(503);
    echo json_encode(['message' => 'No se pudo acceder a los torneos de demostración.']);
}
