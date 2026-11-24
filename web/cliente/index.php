<?php
declare(strict_types=1);
if (str_starts_with($_SERVER['SCRIPT_NAME'], '/cliente/')) {
    $query = http_build_query($_GET);
    header('Location: /' . ($query === '' ? '' : '?' . $query), true, 308);
    exit;
}
require __DIR__ . '/demo.php';
require __DIR__ . '/http.php';
require __DIR__ . '/reservas.php';
require __DIR__ . '/torneos.php';
require __DIR__ . '/../includes/portal-inbox.php';
require __DIR__ . '/../includes/tournament-store.php';
date_default_timezone_set('America/Santiago');
session_name('sgcd_cliente_demo');
session_set_cookie_params(['path' => '/', 'httponly' => true,
    'samesite' => 'Lax', 'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off']);
ini_set('session.use_strict_mode', '1');
session_start();
header('Cache-Control: no-store');

$tournamentStore = new TournamentStore();
try {
    $tournamentCatalog = $tournamentStore->catalog();
} catch (RuntimeException | JsonException) {
    $tournamentCatalog = null;
}
$portal = new DemoPortal($_SESSION['data'] ?? [], date('Y-m-d'), date('H:i'));
if ($tournamentCatalog !== null) $portal->useTournamentBlocks($tournamentCatalog);
$views = ['inicio', 'buscar', 'horarios', 'acceso', 'registro', 'revisar', 'comprobante', 'reservas', 'detalle', 'cuenta', 'ayuda', ...TOURNAMENT_VIEWS];
$view = is_string($_GET['vista'] ?? null) && in_array($_GET['vista'], $views, true) ? $_GET['vista'] : 'inicio';
$_SESSION['csrf'] ??= bin2hex(random_bytes(24));
if (time() - ($_SESSION['active'] ?? 0) > 1800) unset($_SESSION['user'], $_SESSION['receipt']);
$user = $_SESSION['user'] ?? '';
if ($user !== '') $_SESSION['active'] = time();
$profile = $portal->profile($user);
$reviews = portalInbox();
if ($profile) {
    foreach ($portal->history($user) as $item) {
        if (isset($item['request']) && !isset($reviews[$item['request']]) && $item['status'] === 'PENDIENTE') {
            publishPortalRequest($item, $profile['name']);
            $reviews = portalInbox();
        }
    }
}
$portal->syncRequestReviews($reviews);
$portal->useRequestBlocks($reviews);
$filter = $_SESSION['filter'] ?? ['mode' => 'padel', 'date' => $portal->sampleDate(), 'site' => 'rastras', 'blocks' => 1];
$filter['mode'] = isset(DemoPortal::MODES[$filter['mode']]) ? $filter['mode'] : 'padel';
$filter['site'] = 'rastras';
$filter['blocks'] ??= 1;
unset($filter['duration']);
$selection = $_SESSION['selection'] ?? null;
$return = $_SESSION['return'] ?? 'inicio';
$notice = $_SESSION['notice'] ?? null;
unset($_SESSION['notice']);
$loginInput = '';
$errors = [];
$tournamentAccess = in_array($view, ['acceso', 'registro'], true) ? tournamentAccessTarget() : null;
$tournamentAccessQuery = $tournamentAccess ? ['torneo-destino' => $tournamentAccess[0]] + $tournamentAccess[1] : [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hash_equals($_SESSION['csrf'], input('csrf'))) {
        $route = [];
        if (in_array($view, TOURNAMENT_VIEWS, true)) {
            $route = array_filter(['torneo' => tournamentQuery('torneo'), 'equipo' => tournamentQuery('equipo')]);
        }
        go($view, 'El formulario venció. Vuelve a intentarlo.', 'warning', $tournamentAccessQuery + $route);
    }
    $action = input('action');
    if ($tournamentCatalog === null && in_array($action, ['search', 'nearby', 'select', 'recheck', 'send'], true)) {
        go('buscar', 'No pudimos consultar los horarios. Vuelve a intentarlo.');
    }
    handleReservationAction($action, $portal, $filter, $selection, $user, $profile, $errors);

    if ($action === 'login' || $action === 'register') {
        $loginInput = strtolower(input('username'));
        if ($action === 'register') {
            $error = $portal->register(input('name'), input('rut'), $loginInput, passwordInput());
            if ($error) $errors[] = $error;
        } elseif (!$portal->login($loginInput, passwordInput())) $errors[] = 'El usuario o la contraseña de demostración no coinciden.';
        if (!$errors) {
            session_regenerate_id(true);
            $_SESSION['user'] = $loginInput;
            $_SESSION['active'] = time();
            unset($_SESSION['receipt']);
            if ($tournamentAccess) go($tournamentAccess[0], null, 'success', $tournamentAccess[1]);
            if ($return === 'revisar' && $selection) {
                $quote = refreshSelection($filter, $selection, $portal);
                if (!$quote) {
                    unset($_SESSION['selection'], $_SESSION['key']);
                    go('horarios', 'El horario se ocupó mientras iniciabas sesión. Elige otro.');
                }
                if ($quote['total'] !== $selection['total']) {
                    $_SESSION['selection'] = $quote;
                    go('revisar', 'La tarifa cambió. Revisa el nuevo total antes de enviar.');
                }
                go('revisar');
            }
            go($return === 'reservas' ? 'reservas' : 'cuenta');
        }
    }
    if ($action === 'logout') {
        unset($_SESSION['user'], $_SESSION['active'], $_SESSION['receipt'], $_SESSION['selection'], $_SESSION['key'], $_SESSION['return'], $_SESSION['tournament_drafts']);
        session_regenerate_id(true);
        go('inicio');
    }
    if ($action === 'scenario') {
        $scenario = input('scenario');
        $portal->scenario = in_array($scenario, ['SLOT_TAKEN', 'PRICE_CHANGED', 'SESSION_EXPIRED', 'UNAVAILABLE'], true) ? $scenario : '';
        go('ayuda', 'Escenario preparado para el próximo envío.', 'info');
    }
    if ($action === 'reset') {
        $bookings = $portal->snapshot()['bookings'];
        portalInbox(static function (array &$requests) use ($bookings): bool {
            $owned = array_intersect_key($requests, array_flip(array_column($bookings, 'request')));
            if (!$owned) return false;
            $requests = array_diff_key($requests, $owned);
            return true;
        });
        $_SESSION = [];
        session_regenerate_id(true);
        $portal = new DemoPortal([], date('Y-m-d'), date('H:i'));
        if ($tournamentCatalog !== null) $portal->useTournamentBlocks($tournamentCatalog);
        go('inicio', 'La demo se reinició.', 'success');
    }
}

if (in_array($view, ['reservas', 'detalle', 'cuenta', 'revisar'], true) && !$profile) {
    $_SESSION['return'] = $view === 'detalle' ? 'reservas' : $view;
    go('acceso');
}
if ($view === 'revisar') {
    if (!$selection) go('buscar');
    if (!$portal->selectionMatches($filter, $selection)) discardReservationSelection();
}
if ($view === 'horarios' && $tournamentCatalog === null) go('buscar', 'No pudimos consultar los horarios. Vuelve a intentarlo.');
if ($view === 'acceso' && ($_GET['desde'] ?? '') === 'menu') {
    $_SESSION['return'] = 'cuenta';
}
$return = $_SESSION['return'] ?? 'inicio';
$showSelection = !$tournamentAccess && $selection && $return === 'revisar';
$code = is_string($_GET['codigo'] ?? null) ? $_GET['codigo'] : '';
$booking = $view === 'comprobante' ? $portal->receipt($user, $_SESSION['receipt'] ?? '') :
    ($view === 'detalle' ? $portal->detail($user, $code) : null);
if ($view === 'comprobante' && !$booking) go('inicio');
if ($view === 'detalle' && !$booking) go('reservas', 'El detalle no está disponible para esta cuenta.');
$titles = ['inicio' => 'Reserva tu cancha', 'buscar' => 'Buscar disponibilidad', 'horarios' => 'Horarios disponibles',
    'acceso' => 'Iniciar sesión', 'registro' => 'Crear cuenta', 'revisar' => 'Revisa tu reserva', 'comprobante' => 'Solicitud enviada',
    'reservas' => 'Mis reservas', 'detalle' => 'Detalle de reserva', 'cuenta' => 'Mi cuenta', 'ayuda' => 'Ayuda'];
$titles += [
    'torneos' => 'Torneos', 'torneo' => 'Detalle del torneo', 'torneo-equipo' => 'Plantilla del equipo',
    'torneo-revisar' => 'Revisa tu inscripción', 'torneo-inscrito' => 'Inscripción guardada',
    'torneo-inscripcion' => 'Detalle de inscripción', 'mis-inscripciones' => 'Mis inscripciones',
];
if (in_array($view, TOURNAMENT_VIEWS, true)) {
    $tournamentPage = tournamentPortal($view, $profile, $tournamentStore, $tournamentCatalog);
    $view = $tournamentPage['view'];
}
require __DIR__ . '/portal.php';
