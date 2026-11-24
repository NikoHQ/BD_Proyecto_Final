<?php
declare(strict_types=1);

/**
 * Catalogo de solo lectura para las pantallas: recintos con su horario
 * semanal, canchas con las modalidades que admiten y la lista de modalidades.
 * No hay reglas aqui: las decisiones (horizonte, solape, tarifa) viven en los
 * paquetes; esto solo evita que el navegador invente el recinto.
 */

function catalogoFilas(string $sql, array $binds = []): array
{
    $sentencia = authQuery($sql, $binds);
    $filas = [];
    oci_fetch_all($sentencia, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
    oci_free_statement($sentencia);
    return $filas;
}

function catalogoPanel(): array
{
    $recintos = [];
    foreach (catalogoFilas(
        'SELECT ID_RECINTO, NOMBRE_RECINTO, DIRECCION_RECINTO, ESTADO_RECINTO
           FROM SGCD_RECINTOS ORDER BY ID_RECINTO'
    ) as $fila) {
        $recintos[(int) $fila['ID_RECINTO']] = [
            'id' => (int) $fila['ID_RECINTO'],
            'nombre' => $fila['NOMBRE_RECINTO'],
            'direccion' => $fila['DIRECCION_RECINTO'],
            'estado' => $fila['ESTADO_RECINTO'],
            'horarios' => [],
        ];
    }
    foreach (catalogoFilas(
        'SELECT ID_RECINTO, DIA_SEMANA, TRIM(HORA_APERTURA) AS APERTURA, TRIM(HORA_CIERRE) AS CIERRE
           FROM SGCD_HORARIOS ORDER BY ID_RECINTO, DIA_SEMANA'
    ) as $fila) {
        $id = (int) $fila['ID_RECINTO'];
        if (isset($recintos[$id])) {
            $recintos[$id]['horarios'][(int) $fila['DIA_SEMANA']] = [$fila['APERTURA'], $fila['CIERRE']];
        }
    }

    $canchas = [];
    foreach (catalogoFilas(
        'SELECT ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, ESTADO_CANCHA
           FROM SGCD_CANCHAS ORDER BY ID_RECINTO, ID_CANCHA'
    ) as $fila) {
        $canchas[(int) $fila['ID_CANCHA']] = [
            'id' => (int) $fila['ID_CANCHA'],
            'nombre' => $fila['NOMBRE_CANCHA'],
            'tipo' => $fila['TIPO_CANCHA'],
            'estado' => $fila['ESTADO_CANCHA'],
            'recinto' => (int) $fila['ID_RECINTO'],
            'modalidades' => [],
        ];
    }
    foreach (catalogoFilas(
        'SELECT cm.ID_CANCHA, m.ID_MODALIDAD, m.NOMBRE_MODALIDAD, d.NOMBRE_DEPORTE
           FROM SGCD_CANCHAS_MODALIDADES cm
           JOIN SGCD_MODALIDADES m ON m.ID_MODALIDAD = cm.ID_MODALIDAD
           JOIN SGCD_DEPORTES d ON d.ID_DEPORTE = m.ID_DEPORTE
          WHERE m.ESTADO_MODALIDAD = \'ACTIVO\'
          ORDER BY m.ID_MODALIDAD'
    ) as $fila) {
        $id = (int) $fila['ID_CANCHA'];
        if (isset($canchas[$id])) {
            $canchas[$id]['modalidades'][] = [
                'id' => (int) $fila['ID_MODALIDAD'],
                'nombre' => $fila['NOMBRE_MODALIDAD'],
                'deporte' => $fila['NOMBRE_DEPORTE'],
            ];
        }
    }

    $modalidades = array_map(static fn(array $fila): array => [
        'id' => (int) $fila['ID_MODALIDAD'],
        'nombre' => $fila['NOMBRE_MODALIDAD'],
        'deporte' => $fila['NOMBRE_DEPORTE'],
        'maximo' => (int) $fila['MAX_JUGADORES_POR_EQUIPO'],
    ], catalogoFilas(
        'SELECT m.ID_MODALIDAD, m.NOMBRE_MODALIDAD, d.NOMBRE_DEPORTE, m.MAX_JUGADORES_POR_EQUIPO
           FROM SGCD_MODALIDADES m
           JOIN SGCD_DEPORTES d ON d.ID_DEPORTE = m.ID_DEPORTE
          WHERE m.ESTADO_MODALIDAD = \'ACTIVO\'
          ORDER BY d.NOMBRE_DEPORTE, m.NOMBRE_MODALIDAD'
    ));

    $componentes = array_map(static fn(array $fila): array => [
        'grande' => (int) $fila['ID_CANCHA_GRANDE'],
        'pequena' => (int) $fila['ID_CANCHA_PEQUENA'],
    ], catalogoFilas('SELECT ID_CANCHA_GRANDE, ID_CANCHA_PEQUENA FROM SGCD_CANCHAS_COMPONENTES'));

    return [
        'recintos' => array_values($recintos),
        'canchas' => array_values($canchas),
        'modalidades' => $modalidades,
        'componentes' => $componentes,
    ];
}
