<?php
declare(strict_types=1);

function discardReservationSelection(): never
{
    unset($_SESSION['selection'], $_SESSION['key']);
    go('horarios', 'La selección ya no coincide con la búsqueda. Elige de nuevo los bloques y el horario.');
}

function refreshSelection(array $filter, array $selection, DemoPortal $portal): array
{
    if (!$portal->selectionMatches($filter, $selection)) discardReservationSelection();
    return $portal->quote($filter, $selection['court'], $selection['start']) ?? [];
}

function handleReservationAction(
    string $action,
    DemoPortal $portal,
    array &$filter,
    ?array $selection,
    string $user,
    ?array $profile,
    array &$errors
): void {
    if ($action === 'mode' && isset(DemoPortal::MODES[input('mode')])) {
        $filter['mode'] = input('mode');
        $_SESSION['filter'] = $filter;
        unset($_SESSION['selection'], $_SESSION['key']);
        go('buscar');
    }
    if ($action === 'search') {
        $blocks = filter_var(input('blocks'), FILTER_VALIDATE_INT);
        $filter = ['mode' => $filter['mode'], 'date' => input('date'), 'site' => 'rastras',
            'blocks' => $blocks === false ? 0 : $blocks];
        if (!$portal->validFilter($filter)) $errors[] = 'Elige una fecha desde hoy y una cantidad válida de bloques.';
        else {
            $_SESSION['filter'] = $filter;
            unset($_SESSION['selection'], $_SESSION['key']);
            go('horarios');
        }
    }
    if ($action === 'nearby') {
        $day = new DateTimeImmutable(max($filter['date'], $portal->today));
        for ($i = 1; $i <= 7; $i++) {
            $next = array_replace($filter, ['date' => $day->modify("+$i days")->format('Y-m-d')]);
            if ($portal->availability($next)) {
                $_SESSION['filter'] = $next;
                unset($_SESSION['selection'], $_SESSION['key']);
                go('horarios', 'Encontramos horarios en la siguiente fecha disponible.', 'info');
            }
        }
        go('horarios', 'Prueba otra fecha o elige menos bloques.');
    }
    if ($action === 'recheck' && $selection) {
        $quote = refreshSelection($filter, $selection, $portal);
        if (!$quote) {
            unset($_SESSION['selection'], $_SESSION['key']);
            go('horarios', 'El horario se ocupó. Elige otra alternativa.');
        }
        if ($quote['total'] !== $selection['total']) {
            $_SESSION['selection'] = $quote;
            $_SESSION['key'] = bin2hex(random_bytes(16));
            go('revisar', 'La tarifa cambió. Revisa el nuevo total.');
        }
        go('revisar', 'El horario sigue disponible.', 'success');
    }
    if ($action === 'select') {
        [$court, $start] = array_pad(explode('|', input('slot'), 2), 2, '');
        $quote = $portal->quote($filter, $court, $start);
        if (!$quote) go('horarios', 'Ese horario ya no está disponible. Elige otro.');
        $_SESSION['selection'] = $quote;
        $_SESSION['key'] = bin2hex(random_bytes(16));
        $_SESSION['return'] = 'revisar';
        go($profile ? 'revisar' : 'acceso');
    }
    if ($action === 'send') {
        if (!$profile) {
            $_SESSION['return'] = 'revisar';
            go('acceso', 'Tu sesión venció. Ingresa para continuar con tu selección.');
        }
        if (!$selection || !hash_equals($_SESSION['key'] ?? '', input('key'))) go('buscar', 'Selecciona un horario para continuar.');
        $result = submitPortalRequest($portal, $user, $profile['name'], $filter, $selection, input('key'));
        if (($result['error'] ?? '') === 'SELECTION_CHANGED') discardReservationSelection();
        if (($result['error'] ?? '') === 'SLOT_TAKEN') {
            unset($_SESSION['selection'], $_SESSION['key']);
            go('horarios', 'Ese horario se ocupó. Conservamos tus filtros para que elijas otro.');
        }
        if (($result['error'] ?? '') === 'PRICE_CHANGED') {
            $_SESSION['selection'] = $result['quote'];
            $_SESSION['key'] = bin2hex(random_bytes(16));
            go('revisar', 'La tarifa cambió. Revisa el nuevo total y vuelve a enviar si estás de acuerdo.');
        }
        if (($result['error'] ?? '') === 'SESSION_EXPIRED') {
            unset($_SESSION['user'], $_SESSION['active']);
            $_SESSION['return'] = 'revisar';
            go('acceso', 'Tu sesión venció. Tu selección sigue guardada.');
        }
        if (!isset($result['booking'])) go('revisar', 'No pudimos procesar la solicitud. Puedes volver a intentarlo.');
        $_SESSION['receipt'] = $result['booking']['code'];
        $_SESSION['return'] = 'inicio';
        go('comprobante');
    }
    if ($action === 'cancel') {
        $code = input('code');
        $bookingToCancel = $portal->detail($user, $code);
        if ($portal->cancel($user, $code)) {
            if (isset($bookingToCancel['request'])) {
                reviewPortalRequest($bookingToCancel['request'], 'CANCELADA', false);
                $portal->syncRequestReviews(portalInbox());
            }
            go('detalle', 'La reserva fue cancelada.', 'success', ['codigo' => $code]);
        }
        go('reservas', 'La reserva ya no admite cancelación.');
    }
}
