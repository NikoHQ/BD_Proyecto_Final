<?php
declare(strict_types=1);

const TOURNAMENT_VIEWS = ['torneos', 'torneo', 'torneo-equipo', 'torneo-revisar', 'torneo-inscrito', 'torneo-inscripcion', 'mis-inscripciones'];
const TOURNAMENT_PRIVATE_VIEWS = ['torneo-equipo', 'torneo-revisar', 'torneo-inscrito', 'torneo-inscripcion', 'mis-inscripciones'];

function tournamentQuery(string $key): string
{
    $value = $_GET[$key] ?? '';
    return is_string($value) ? $value : '';
}

function tournamentAccessTarget(): ?array
{
    $target = tournamentQuery('torneo-destino');
    if (!in_array($target, TOURNAMENT_PRIVATE_VIEWS, true)) return null;

    $parameters = [];
    foreach (['torneo', 'equipo'] as $key) {
        $value = tournamentQuery($key);
        if ($value !== '') $parameters[$key] = $value;
    }
    return [$target, $parameters];
}

function tournamentById(array $rows, string $id): ?array
{
    foreach ($rows as $row) {
        if ((string) $row['id'] === $id) return $row;
    }
    return null;
}

function tournamentCanEdit(array $tournament): bool
{
    return $tournament['canManage'];
}

function tournamentNewDraft(int $size, ?array $team): array
{
    return [
        'key' => bin2hex(random_bytes(16)), 'size' => $size, 'validated' => false,
        'name' => $team['name'] ?? '', 'players' => array_slice($team['players'] ?? [], 1),
    ];
}

function tournamentDraftInputs(array $draft): array
{
    $draft['name'] = input('team_name');
    $draft['validated'] = false;
    unset($draft['reviewKey'], $draft['review']);
    $names = is_array($_POST['player_name'] ?? null) ? $_POST['player_name'] : [];
    $ruts = is_array($_POST['player_rut'] ?? null) ? $_POST['player_rut'] : [];
    $draft['players'] = [];
    foreach (array_slice(array_keys($names + $ruts), 0, 50) as $index) {
        $draft['players'][] = [
            'name' => is_string($names[$index] ?? null) ? trim($names[$index]) : '',
            'rut' => is_string($ruts[$index] ?? null) ? trim($ruts[$index]) : '',
        ];
    }
    return $draft;
}

function tournamentFieldErrors(array $draft, array $captain): array
{
    $errors = [];
    if ($draft['size'] > 1 && ($draft['name'] === '' || !preg_match('/^[^\p{C}]{1,100}$/uD', $draft['name']))) {
        $errors['team_name'] = 'Ingresa un nombre de equipo de hasta 100 caracteres.';
    }
    $seen = [TournamentStore::normalizeRut($captain['rut']) => true];
    foreach ($draft['players'] as $i => $player) {
        if (!preg_match('/^[^\p{C}]{1,100}$/uD', $player['name'])) {
            $errors['name'][$i] = 'Ingresa un nombre completo de hasta 100 caracteres.';
        }
        $rut = TournamentStore::normalizeRut($player['rut']);
        if ($rut === null) {
            $errors['rut'][$i] = 'Ingresa un RUT válido con dígito verificador.';
        } elseif (isset($seen[$rut])) {
            $errors['rut'][$i] = 'Este RUT ya está en la plantilla, incluido el capitán.';
        } else {
            $seen[$rut] = true;
        }
    }
    return $errors;
}

function tournamentPortal(string $view, ?array $profile, TournamentStore $store, ?array $catalog): array
{
    $id = tournamentQuery('torneo');
    $teamId = tournamentQuery('equipo');
    $route = $id === '' ? [] : ['torneo' => $id];
    if ($teamId !== '') $route['equipo'] = $teamId;
    $action = $_SERVER['REQUEST_METHOD'] === 'POST' ? input('action') : '';

    if (in_array($view, TOURNAMENT_PRIVATE_VIEWS, true) && !$profile) {
        if ($action === 'tournament-review') {
            // An expired form may update only the draft that issued its token.
            foreach ($_SESSION['tournament_drafts'] ?? [] as $owner => $drafts) {
                $pending = $drafts[$id][$teamId] ?? null;
                if ($pending && empty($pending['saved']) && hash_equals($pending['key'], input('draft_key'))) {
                    $_SESSION['tournament_drafts'][$owner][$id][$teamId] = tournamentDraftInputs($pending);
                    break;
                }
            }
        }
        go('acceso', null, 'warning', ['torneo-destino' => $view] + $route);
    }

    try {
        if ($catalog === null) throw new RuntimeException('Catálogo no disponible.');
        $entries = $profile ? $store->entries($profile['rut'], $profile['identity']) : [];
    } catch (RuntimeException | JsonException) {
        http_response_code(503);
        return ['view' => 'torneos', 'catalog' => [], 'unavailable' => true];
    }
    $tournament = tournamentById($catalog, $id);
    $team = tournamentById($entries, $teamId);
    if ($team && (string) $team['tournamentId'] !== $id) $team = null;

    $activeTeam = null;
    foreach ($entries as $entry) {
        if ((string) $entry['tournamentId'] === $id && !$entry['withdrawn']) {
            $activeTeam = $entry;
            break;
        }
    }

    if (!in_array($view, ['torneos', 'mis-inscripciones'], true) && !$tournament) {
        go('torneos', 'El torneo ya no está disponible.');
    }
    if (in_array($view, ['torneo-inscrito', 'torneo-inscripcion'], true) && !$team) {
        go('mis-inscripciones', 'La inscripción no está disponible para esta cuenta.');
    }

    $draft = null;
    $fieldErrors = [];
    $formError = '';
    $flow = in_array($view, ['torneo-equipo', 'torneo-revisar'], true);
    if ($flow) {
        $owner = $profile['identity'];
        if ($teamId !== '' && !$team) go('mis-inscripciones', 'La inscripción no está disponible para esta cuenta.');
        if ($teamId === '' && $activeTeam && $action !== 'tournament-confirm') {
            go('torneo-inscripcion', null, 'warning', ['torneo' => $id, 'equipo' => $activeTeam['id']]);
        }
        $sessionDraft = &$_SESSION['tournament_drafts'][$owner][$id][$teamId];
        if ($action === 'tournament-confirm' && !empty($sessionDraft['saved'])
            && isset($sessionDraft['reviewKey']) && hash_equals($sessionDraft['reviewKey'], input('draft_key'))) {
            go('torneo-inscrito', null, 'success', ['torneo' => $id, 'equipo' => $sessionDraft['saved']]);
        }

        $matchesDraft = $action === 'tournament-review'
            && $sessionDraft && empty($sessionDraft['saved']) && hash_equals($sessionDraft['key'], input('draft_key'));
        if ($matchesDraft) $sessionDraft = tournamentDraftInputs($sessionDraft);

        $canProceed = $team ? !$team['withdrawn'] && tournamentCanEdit($tournament) : $tournament['registration'] === 'OPEN';
        $retryConfirmation = $action === 'tournament-confirm' && !empty($sessionDraft['validated'])
            && isset($sessionDraft['reviewKey']) && hash_equals($sessionDraft['reviewKey'], input('draft_key'));
        if (!$canProceed && !$retryConfirmation) {
            $message = $tournament['registration'] === 'FULL' && !$team ? 'Se agotaron los cupos de este torneo.' : 'El torneo ya no admite este cambio.';
            go($team ? 'torneo-inscripcion' : 'torneo', $message, 'warning', $route);
        }
        if (!$sessionDraft || !empty($sessionDraft['saved'])) $sessionDraft = tournamentNewDraft((int) $tournament['teamSize'], $team);

        if ((int) $tournament['teamSize'] !== $sessionDraft['size']) {
            $sessionDraft['size'] = (int) $tournament['teamSize'];
            $sessionDraft['validated'] = false;
            unset($sessionDraft['reviewKey'], $sessionDraft['review']);
            $remaining = $sessionDraft['size'] - 1 - count($sessionDraft['players']);
            $adjustment = match (true) {
                $remaining > 0 => ' Completa ' . $remaining . ($remaining === 1 ? ' lugar adicional.' : ' lugares adicionales.'),
                $remaining < 0 => ' La plantilla ahora tiene ' . -$remaining . ($remaining === -1 ? ' lugar menos.' : ' lugares menos.'),
                default => '',
            };
            $formError = 'Cambió la cantidad de jugadores.' . $adjustment . ' Revisa la plantilla antes de continuar.';
            $view = 'torneo-equipo';
        } elseif (in_array($action, ['tournament-review', 'tournament-confirm'], true)) {
            $matchesReview = $action === 'tournament-confirm'
                && isset($sessionDraft['reviewKey']) && hash_equals($sessionDraft['reviewKey'], input('draft_key'));
            if (!$matchesDraft && !$matchesReview) {
                $formError = 'El formulario venció. Vuelve a revisar la plantilla.';
                $view = 'torneo-equipo';
            } else {
                try {
                    if ($action === 'tournament-review') {
                        $fieldErrors = tournamentFieldErrors($sessionDraft, $profile);
                        if ($fieldErrors) {
                            $formError = 'Revisa los campos marcados.';
                        } else {
                            $sessionDraft['review'] = $store->validateTeam($id, $profile, $sessionDraft['name'], $sessionDraft['players'], $teamId ?: null, $sessionDraft['size']);
                            $sessionDraft['validated'] = true;
                            $sessionDraft['reviewKey'] = bin2hex(random_bytes(16));
                            go('torneo-revisar', null, 'success', $route);
                        }
                    } elseif ($sessionDraft['validated']) {
                        $saved = $store->saveTeam($id, $profile, $sessionDraft['name'], $sessionDraft['players'], $sessionDraft['reviewKey'], $teamId ?: null, $sessionDraft['size']);
                        $sessionDraft['saved'] = (string) $saved['id'];
                        go('torneo-inscrito', $team ? 'Cambios guardados.' : null, 'success', ['torneo' => $id, 'equipo' => $saved['id']]);
                    }
                } catch (TournamentRule $exception) {
                    $formError = $exception->getMessage();
                    $sessionDraft['validated'] = false;
                } catch (RuntimeException | JsonException) {
                    if ($action === 'tournament-confirm' && $sessionDraft['validated']) {
                        go('torneo-revisar', 'No pudimos confirmar el guardado. Puedes reintentar con el mismo formulario.', 'warning', $route);
                    }
                    $formError = 'No pudimos revisar la plantilla. Vuelve a intentarlo.';
                }
                $view = 'torneo-equipo';
            }
        }
        if ($view === 'torneo-revisar' && !$sessionDraft['validated']) go('torneo-equipo', null, 'warning', $route);
        $draft = $sessionDraft;
    }

    if ($view === 'torneo-inscripcion' && $action === 'tournament-withdraw') {
        try {
            $store->withdrawTeam($id, $teamId, $profile['rut'], $profile['identity']);
            unset($_SESSION['tournament_drafts'][$profile['identity']][$id][$teamId]);
            go('torneo-inscripcion', 'El equipo se retiró y su cupo quedó disponible.', 'success', $route);
        } catch (TournamentRule $exception) {
            go('torneo-inscripcion', $exception->getMessage(), 'warning', $route);
        } catch (RuntimeException | JsonException) {
            go('torneo-inscripcion', 'No pudimos confirmar el retiro. Puedes volver a intentarlo.', 'warning', $route);
        }
    }

    return compact('view', 'catalog', 'tournament', 'entries', 'team', 'activeTeam', 'draft', 'route', 'formError', 'fieldErrors');
}
