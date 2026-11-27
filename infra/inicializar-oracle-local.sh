#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

update_packages=false
load_demo_data=false
for option in "$@"; do
    case "$option" in
        --actualizar-paquetes) update_packages=true ;;
        --datos-demo) load_demo_data=true ;;
        *) echo 'Uso: inicializar-oracle-local.sh [--actualizar-paquetes] [--datos-demo]' >&2; exit 2 ;;
    esac
done

# Lee la configuración de Compose sin imprimir ni pasar la clave como argumento.
db_password="$(docker compose config --format json | python3 -c '
import json, sys
print(json.load(sys.stdin)["services"]["app"]["environment"]["SGCD_DB_PASSWORD"])
')"
if [[ -z "$db_password" || "$db_password" == *\"* || "$db_password" == *$'\n'* || "$db_password" == *$'\r'* ]]; then
    echo 'SGCD_DB_PASSWORD debe contener una clave de Oracle sin comillas dobles ni saltos de línea.' >&2
    exit 1
fi

sqlplus() {
    docker compose exec -T -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 oracle sqlplus -s -L "$@"
}

sql_admin() {
    {
        printf '%s\n' 'whenever sqlerror exit failure rollback' 'whenever oserror exit failure' \
            'set define off echo off verify off pagesize 0 heading off feedback off' 'alter session set container=FREEPDB1;'
        cat
        printf '\nexit\n'
    } | sqlplus / as sysdba
}

sql_sgcd19() {
    {
        printf '%s\n' 'whenever sqlerror exit failure rollback' 'whenever oserror exit failure' \
            'set define off echo off verify off'
        printf 'connect SGCD19/"%s"@localhost/FREEPDB1\n' "$db_password"
        cat
        printf '\nexit\n'
    } | sqlplus /nolog
}

run_checked() {
    local report
    if ! report="$("$@")" || [[ "$report" == *SP2-* || "$report" == *Warning:* ]]; then
        printf '%s\n' "${report//"$db_password"/[clave oculta]}" >&2
        return 1
    fi
    printf '%s\n' "$report"
}

schema_state="$(run_checked sql_admin <<'SQL'
select case
    when not exists (select 1 from dba_users where username = 'SGCD19') then 'AUSENTE'
    when exists (select 1 from dba_objects where owner = 'SGCD19' and object_name not like 'BIN$%') then 'OCUPADO'
    else 'VACIO'
end from dual;
SQL
)"
case "$schema_state" in
    AUSENTE)
        {
            printf 'create user SGCD19 identified by "%s" default tablespace USERS quota unlimited on USERS;\n' "$db_password"
            printf '%s\n' 'grant create session, create table, create sequence, create trigger, create procedure to SGCD19;'
        } | run_checked sql_admin
        ;;
    VACIO) ;;
    OCUPADO)
        if "$update_packages"; then
            echo 'SGCD19 ya contiene objetos. Se actualizará el código PL/SQL.'
        else
            echo 'SGCD19 ya contiene objetos. Se verificará el modelo sin volver a cargarlo.'
        fi
        ;;
    *) printf '%s\n' "No se pudo determinar el estado de SGCD19: $schema_state" >&2; exit 1 ;;
esac

load_scripts() {
    local script
    for script in "$@"; do
        printf 'prompt Instalando %s\n' "$script"
        cat "$script"
        printf '\n'
    done
}

if [[ "$schema_state" != OCUPADO ]]; then
    echo 'Instalando el modelo objetivo en SGCD19.'
    {
        cat <<'SQL'
declare
    object_count number;
begin
    select count(*) into object_count from user_objects where object_name not like 'BIN$%';
    if user <> 'SGCD19' or object_count > 0 then
        raise_application_error(-20999, 'La instalación requiere el esquema SGCD19 vacío');
    end if;
end;
/
SQL
        load_scripts sql/oracle/10_ddl_sgcd_19.sql sql/oracle/16_rango_plantilla_torneos.sql sql/oracle/11_catalogos_sgcd_19.sql sql/oracle/12*.sql
    } | run_checked sql_sgcd19
elif "$update_packages"; then
    {
        cat <<'SQL'
declare
    table_count number;
    key_table number;
begin
    select count(*) into table_count from user_tables where table_name like 'SGCD\_%' escape '\';
    select count(*) into key_table from user_tables where table_name = 'SGCD_USUARIOS';
    if user <> 'SGCD19' or table_count <> 19 or key_table <> 1 then
        raise_application_error(-20999, 'La actualización requiere el esquema objetivo SGCD19');
    end if;
end;
/
SQL
        load_scripts sql/oracle/16_rango_plantilla_torneos.sql sql/oracle/12*.sql
    } | run_checked sql_sgcd19
fi

run_checked sql_sgcd19 <<'SQL'
set serveroutput on feedback off
declare
    tables_present number;
    key_table number;
    packages_present number;
    bodies_present number;
    invalid_objects number;
begin
    select count(*) into tables_present from user_tables where table_name like 'SGCD\_%' escape '\';
    select count(*) into key_table from user_tables where table_name = 'SGCD_USUARIOS';
    select count(*) into packages_present from user_objects where object_type = 'PACKAGE' and object_name like 'SGCD\_PKG\_%' escape '\';
    select count(*) into bodies_present from user_objects where object_type = 'PACKAGE BODY' and object_name like 'SGCD\_PKG\_%' escape '\';
    select count(*) into invalid_objects from user_objects where status = 'INVALID';
    if tables_present <> 19 or key_table <> 1 or packages_present <> 7 or bodies_present <> 7 or invalid_objects <> 0 then
        raise_application_error(-20998, 'SGCD19 incompleto: tablas=' || tables_present || ', paquetes=' ||
            packages_present || ', cuerpos=' || bodies_present || ', invalidos=' || invalid_objects);
    end if;
    dbms_output.put_line('SGCD19: 19 tablas, 7 paquetes, 0 objetos inválidos.');
end;
/
SQL


if "$load_demo_data"; then
    load_scripts sql/oracle/15_datos_operativos_sgcd_19.sql | run_checked sql_sgcd19
fi
