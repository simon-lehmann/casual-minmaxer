#!/usr/bin/env bash
# Start (or restart) the MariaDB container with the CMaNGOS TBC-DB loaded.
# Usage: scripts/db-up.sh /path/to/tbc-db-checkout
set -euo pipefail
DB_DIR=${1:?path to cmangos/tbc-db checkout}
NAME=${CMM_DB_CONTAINER:-cmm-mariadb}
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -e MARIADB_ROOT_PASSWORD=root -e MARIADB_DATABASE=tbcmangos \
  -v "$(realpath "$DB_DIR"):/db:ro" -p 127.0.0.1:33306:3306 mariadb:11 --max_allowed_packet=256M >/dev/null
for _ in $(seq 1 60); do docker exec "$NAME" mariadb -uroot -proot -e "select 1" >/dev/null 2>&1 && break; sleep 2; done
docker exec "$NAME" sh -c 'gunzip -c /db/Full_DB/*.sql.gz | mariadb -uroot -proot tbcmangos'
for f in $(ls "$DB_DIR"/Updates/*.sql | sort -V); do
  docker exec "$NAME" sh -c "mariadb -uroot -proot tbcmangos < /db/Updates/$(basename "$f")"
done
# Spell DBC dump from the core repo (spell_template)
TMP=$(mktemp -d)
curl -sL -o "$TMP/Spell.sql" https://raw.githubusercontent.com/cmangos/mangos-tbc/master/sql/base/dbc/original_data/Spell.sql
curl -sL -o "$TMP/Spell_fixes.sql" https://raw.githubusercontent.com/cmangos/mangos-tbc/master/sql/base/dbc/cmangos_fixes/Spell.sql
docker cp "$TMP/Spell.sql" "$NAME:/tmp/Spell.sql"; docker cp "$TMP/Spell_fixes.sql" "$NAME:/tmp/Spell_fixes.sql"
docker exec "$NAME" sh -c 'mariadb -uroot -proot tbcmangos < /tmp/Spell.sql && mariadb -uroot -proot tbcmangos < /tmp/Spell_fixes.sql'
rm -rf "$TMP"
echo "database ready in container $NAME"
