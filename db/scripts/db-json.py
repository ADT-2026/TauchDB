#!/usr/bin/env python3
"""Package, check and import explicit AI-authored JSON; never generate test records."""
import argparse
from collections import Counter
from datetime import date, datetime
from decimal import Decimal
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/ai-direct.rows.json'
TARGET = ROOT / 'data/ai-direct.json'
REFS = {
    'customers': {}, 'instructors': {}, 'certifications': {},
    'customer_certifications': {'customer_id': 'customers', 'certification_id': 'certifications'},
    'instructor_certifications': {'instructor_id': 'instructors', 'certification_id': 'certifications'},
    'courses': {'required_certification_id': 'certifications'},
    'dive_sites': {'required_certification_id': 'certifications'},
    'course_sessions': {'course_id': 'courses', 'instructor_id': 'instructors'},
    'dive_trips': {'site_id': 'dive_sites', 'instructor_id': 'instructors'},
    'bookings': {'customer_id': 'customers', 'session_id': 'course_sessions', 'trip_id': 'dive_trips'},
    'equipment': {}, 'equipment_allocations': {'equipment_id': 'equipment'},
    'equipment_rentals': {'allocation_id': 'equipment_allocations', 'customer_id': 'customers'},
    'equipment_assignments': {'allocation_id': 'equipment_allocations', 'booking_id': 'bookings'},
    'equipment_maintenance': {'allocation_id': 'equipment_allocations'},
    'invoices': {'customer_id': 'customers', 'booking_id': 'bookings', 'rental_id': 'equipment_rentals'},
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f'Duplicate JSON key: {key}')
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_keys)


def expand():
    """Lossless column-to-object conversion; all values already exist in SOURCE."""
    source = read_json(SOURCE)
    tables = {}
    for name, table in source['tables'].items():
        columns = table['columns']
        defaults = table.get('defaults', {})
        require(len(columns) == len(set(columns)), f'{name}: duplicate columns')
        require(not set(columns) & set(defaults), f'{name}: defaults shadow row columns')
        rows = []
        for values in table['rows']:
            require(len(values) == len(columns), f'{name}: row width mismatch')
            rows.append({**defaults, **dict(zip(columns, values))})
        tables[name] = rows
    return {'metadata': source['metadata'], 'tables': tables}


def timestamp(value):
    parsed = datetime.fromisoformat(value)
    require(parsed.utcoffset() is not None, f'Timezone missing: {value}')
    return parsed


def berlin_day(value):
    return timestamp(value).astimezone(ZoneInfo('Europe/Berlin')).date()


def validate(data):
    tables = data['tables']
    require(set(tables) == set(REFS), 'Expected exactly the 16 schema tables')
    require(len(tables['customers']) == 1000, 'Expected 1000 directly authored customers')
    schema = (ROOT / 'prisma/schema.prisma').read_text()
    enums = {name: set(body.split()) for name, body in re.findall(r'enum (\w+)\s*\{([^}]+)\}', schema)}
    scalar_types = {'Int', 'String', 'Boolean', 'Decimal', 'DateTime'} | set(enums)
    models = {}
    for _, body in re.findall(r'model (\w+)\s*\{([^}]+)\}', schema):
        mapped = re.search(r'@@map\("(\w+)"\)', body)
        if mapped:
            fields = {}
            for line in body.splitlines():
                parts = line.split()
                if len(parts) >= 2 and parts[1].rstrip('?') in scalar_types:
                    fields[parts[0]] = (parts[1], line)
            models[mapped[1]] = fields
    by_id = {}
    for name, rows in tables.items():
        require(rows and all(isinstance(row, dict) for row in rows), f'{name}: empty or invalid rows')
        fields = models[name]
        ids = [row['id'] for row in rows]
        require(len(ids) == len(set(ids)), f'{name}: duplicate IDs')
        by_id[name] = {row['id']: row for row in rows}
        require(all(set(row) == set(rows[0]) for row in rows), f'{name}: inconsistent column sets')
        for row in rows:
            require(set(row) <= set(fields), f'{name}: unknown schema columns')
            for field, (kind, declaration) in fields.items():
                nullable = kind.endswith('?')
                if field not in row:
                    require(nullable or '@default(' in declaration, f'{name}: required field {field} missing')
                    continue
                value = row[field]
                if value is None:
                    require(nullable, f'{name}.{field}: NULL forbidden')
                    continue
                kind = kind.rstrip('?')
                if kind == 'Int':
                    require(type(value) is int, f'{name}.{field}: expected integer')
                elif kind == 'Boolean':
                    require(type(value) is bool, f'{name}.{field}: expected boolean')
                elif kind == 'String':
                    require(isinstance(value, str), f'{name}.{field}: expected string')
                elif kind == 'Decimal':
                    require(type(value) in (int, float), f'{name}.{field}: expected number')
                    amount = Decimal(str(value))
                    require(amount.is_finite() and amount == amount.quantize(Decimal('.01')) and abs(amount) < 100000000,
                            f'{name}.{field}: not Decimal(10,2)')
                elif kind == 'DateTime':
                    date.fromisoformat(value) if '@db.Date ' in declaration or declaration.rstrip().endswith('@db.Date') else timestamp(value)
                else:
                    require(value in enums[kind], f'{name}.{field}: invalid enum value')
    for name, rows in tables.items():
        for row in rows:
            for field, parent in REFS[name].items():
                require(row.get(field) is None or row[field] in by_id[parent], f'{name}.{field}: unknown reference')
    for name, columns in {
        'customers': [('email',)], 'instructors': [('email',)],
        'certifications': [('name', 'organization')],
        'customer_certifications': [('certification_id', 'certificate_number')],
        'instructor_certifications': [('certification_id', 'certificate_number')],
        'equipment': [('inventory_number',)],
        'equipment_rentals': [('allocation_id',)], 'equipment_assignments': [('allocation_id',)],
        'equipment_maintenance': [('allocation_id',)],
        'invoices': [('invoice_number',), ('booking_id',), ('rental_id',)],
    }.items():
        for fields in columns:
            keys = [tuple(row.get(field).lower() if field == 'email' else row.get(field) for field in fields)
                    for row in tables[name] if all(row.get(field) is not None for field in fields)]
            require(len(keys) == len(set(keys)), f'{name}: duplicate {fields}')
    for name in ('customer_certifications', 'instructor_certifications'):
        owner = 'customer_id' if name.startswith('customer') else 'instructor_id'
        for index, row in enumerate(tables[name]):
            start = date.fromisoformat(row['issued_at'])
            end = date.fromisoformat(row['expires_at']) if row['expires_at'] else date.max
            require(end >= start, f'{name}: expiry before issue')
            for other in tables[name][:index]:
                if (row[owner], row['certification_id']) == (other[owner], other['certification_id']):
                    other_end = date.fromisoformat(other['expires_at']) if other['expires_at'] else date.max
                    require(end < date.fromisoformat(other['issued_at']) or other_end < start, f'{name}: overlapping validity')
    for name in ('courses', 'dive_trips', 'equipment_rentals', 'equipment_maintenance', 'invoices'):
        field = {'equipment_maintenance': 'cost', 'invoices': 'total_amount'}.get(name, 'price')
        require(all(row[field] >= 0 for row in tables[name]), f'{name}: negative amount')
    require(all(row['duration_days'] > 0 for row in tables['courses']), 'Nonpositive course duration')
    require(all(row['max_depth_meters'] > 0 for row in tables['dive_sites']), 'Nonpositive site depth')
    schedules = tables['course_sessions'] + tables['dive_trips']
    for index, row in enumerate(schedules):
        require(timestamp(row['end_at']) > timestamp(row['start_at']) and row['max_participants'] > 0, 'Invalid schedule')
        if row['status'] == 'cancelled':
            continue
        require(by_id['instructors'][row['instructor_id']]['active'], 'Inactive instructor scheduled')
        for other in schedules[:index]:
            if other['status'] != 'cancelled' and other['instructor_id'] == row['instructor_id']:
                require(not overlaps(row, other), 'Instructor overlap')
    counts = Counter()
    active = set()
    snapshot = timestamp(data['metadata']['snapshot'])
    for row in tables['bookings']:
        require((row['session_id'] is None) != (row['trip_id'] is None), 'Booking needs exactly one target')
        name, key = ('course_sessions', 'session_id') if row['session_id'] else ('dive_trips', 'trip_id')
        event = by_id[name][row[key]]
        require(timestamp(row['booked_at']) <= min(snapshot, timestamp(event['start_at'])), 'Invalid booking date')
        require(timestamp(row['booked_at']) >= timestamp(by_id['customers'][row['customer_id']]['created_at']), 'Booking before registration')
        if row['passed_at']:
            require(row['session_id'] and row['booking_status'] == 'confirmed'
                    and timestamp(event['end_at']) <= timestamp(row['passed_at']) <= snapshot, 'Invalid course pass')
        if row['booking_status'] == 'cancelled':
            continue
        require(event['status'] != 'cancelled', 'Confirmed booking on cancelled event')
        signature = (row['customer_id'], name, row[key])
        require(signature not in active, 'Duplicate active booking')
        active.add(signature)
        counts[name, row[key]] += 1
        require(counts[name, row[key]] <= event['max_participants'], 'Overbooked event')
        offer = by_id['courses'][event['course_id']] if row['session_id'] else by_id['dive_sites'][event['site_id']]
        needed = offer['required_certification_id']
        day = berlin_day(event['start_at'])
        require(needed is None or any(c['customer_id'] == row['customer_id'] and c['certification_id'] == needed
                and date.fromisoformat(c['issued_at']) <= day
                and (c['expires_at'] is None or date.fromisoformat(c['expires_at']) >= day)
                for c in tables['customer_certifications']), 'Required certificate missing or expired')
    details = Counter()
    for name, kind in [('equipment_rentals', 'rental'), ('equipment_assignments', 'assignment'), ('equipment_maintenance', 'maintenance')]:
        for row in tables[name]:
            allocation = by_id['equipment_allocations'][row['allocation_id']]
            require(row['allocation_type'] == allocation['allocation_type'] == kind, 'Allocation type mismatch')
            details[row['allocation_id']] += 1
            if row.get('returned_at'):
                require(timestamp(allocation['start_at']) <= timestamp(row['returned_at']) <= snapshot, 'Invalid return time')
            if name == 'equipment_assignments':
                booking = by_id['bookings'][row['booking_id']]
                event = by_id['course_sessions'][booking['session_id']] if booking['session_id'] else by_id['dive_trips'][booking['trip_id']]
                require(booking['booking_status'] == 'confirmed' and allocation['start_at'] == event['start_at']
                        and allocation['end_at'] == event['end_at'], 'Assignment does not match booking')
    for index, row in enumerate(tables['equipment_allocations']):
        require(timestamp(row['end_at']) > timestamp(row['start_at']), 'Invalid allocation interval')
        require(details[row['id']] == 1, 'Allocation needs exactly one detail')
        if row['status'] == 'cancelled':
            continue
        equipment = by_id['equipment'][row['equipment_id']]
        require(equipment['retired_at'] is None or berlin_day(row['end_at']) < date.fromisoformat(equipment['retired_at']), 'Retired equipment allocated')
        require((timestamp(row['end_at']) <= snapshot) == (row['status'] == 'completed'), 'Allocation status inconsistent with snapshot')
        for other in tables['equipment_allocations'][:index]:
            if other['status'] != 'cancelled' and other['equipment_id'] == row['equipment_id']:
                require(not overlaps(row, other), 'Equipment overlap')
    for row in tables['invoices']:
        require((row['booking_id'] is None) != (row['rental_id'] is None), 'Invoice needs exactly one source')
        require(row['invoice_number'].strip(), 'Empty invoice number')
        if row['booking_id']:
            source = by_id['bookings'][row['booking_id']]
            require(source['booking_status'] == 'confirmed', 'Invoice on cancelled booking')
            amount = by_id['courses'][by_id['course_sessions'][source['session_id']]['course_id']]['price'] if source['session_id'] else by_id['dive_trips'][source['trip_id']]['price']
        else:
            source = by_id['equipment_rentals'][row['rental_id']]
            require(by_id['equipment_allocations'][source['allocation_id']]['status'] != 'cancelled', 'Invoice on cancelled rental')
            amount = source['price']
        require(row['customer_id'] == source['customer_id'] and Decimal(str(row['total_amount'])) == Decimal(str(amount)), 'Invoice customer or amount mismatch')
        require(date.fromisoformat(row['issued_at']) <= date.fromisoformat(row['due_at']) and date.fromisoformat(row['issued_at']) <= snapshot.date(), 'Invalid invoice dates')
        require(row['paid_at'] is None or date.fromisoformat(row['issued_at']) <= berlin_day(row['paid_at']) <= snapshot.date(), 'Invalid payment date')
    return {name: len(rows) for name, rows in tables.items()}


def overlaps(a, b):
    return timestamp(a['start_at']) < timestamp(b['end_at']) and timestamp(b['start_at']) < timestamp(a['end_at'])


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def import_sql(data, commit):
    """Translate existing values and remap local IDs; no synthetic value generation."""
    statements = [
        'BEGIN;', "SET LOCAL search_path = public, pg_temp;",
        "SET LOCAL TIME ZONE 'Europe/Berlin';", 'SET LOCAL standard_conforming_strings = on;',
        "SELECT pg_advisory_xact_lock(hashtext('ai-json-import'), hashtext(" + literal(data['metadata']['dataset']) + '));',
        "DO $$ BEGIN IF to_regprocedure('public.enforce_booking_rules()') IS NULL THEN RAISE EXCEPTION 'Apply both Prisma migrations first'; END IF; END $$;",
        'DO $$ BEGIN IF EXISTS (SELECT 1 FROM public.customers WHERE lower(email) LIKE ' + literal('%@' + data['metadata']['email_domain']) + ") THEN RAISE EXCEPTION 'Direct JSON dataset already imported'; END IF; END $$;",
        'CREATE TEMP TABLE _ai_json_rows (table_name text, local_id integer, payload jsonb, PRIMARY KEY(table_name,local_id)) ON COMMIT DROP;',
        'CREATE TEMP TABLE _ai_json_ids (table_name text, local_id integer, db_id integer, PRIMARY KEY(table_name,local_id)) ON COMMIT DROP;',
    ]
    for name in REFS:
        payload = literal(json.dumps(data['tables'][name], ensure_ascii=False, allow_nan=False))
        statements.append(f"INSERT INTO _ai_json_rows SELECT '{name}', (v->>'id')::integer, v FROM jsonb_array_elements({payload}::jsonb) v;")
    statements.append("INSERT INTO _ai_json_ids SELECT table_name, local_id, nextval(pg_get_serial_sequence('public.' || table_name, 'id'))::integer FROM _ai_json_rows ORDER BY table_name,local_id;")
    for name, refs in REFS.items():
        columns = list(data['tables'][name][0])
        names = ', '.join('"' + field + '"' for field in columns)
        selected = ', '.join('r."' + field + '"' for field in columns)
        replacements = ["'id'", 'own.db_id']
        for field, parent in refs.items():
            replacements += [literal(field), f"(SELECT db_id FROM _ai_json_ids WHERE table_name='{parent}' AND local_id=(s.payload->>'{field}')::integer)"]
        amended = 's.payload || jsonb_build_object(' + ', '.join(replacements) + ')'
        statements.append(f'''INSERT INTO public."{name}" ({names})
SELECT {selected} FROM _ai_json_rows s
JOIN _ai_json_ids own ON own.table_name=s.table_name AND own.local_id=s.local_id
CROSS JOIN LATERAL jsonb_populate_record(NULL::public."{name}", {amended}) r
WHERE s.table_name='{name}' ORDER BY s.local_id;''')
    statements += [
        'SET CONSTRAINTS ALL IMMEDIATE;',
        """DO $$ DECLARE t text; actual bigint; expected bigint; BEGIN
FOR t IN SELECT DISTINCT table_name FROM _ai_json_rows LOOP
  SELECT count(*) INTO expected FROM _ai_json_rows WHERE table_name=t;
  EXECUTE format('SELECT count(*) FROM public.%I r JOIN pg_temp._ai_json_ids m ON r.id=m.db_id WHERE m.table_name=$1',t) INTO actual USING t;
  IF actual <> expected THEN RAISE EXCEPTION 'Row count mismatch for %',t; END IF;
END LOOP; END $$;""",
        'SELECT table_name, count(*) AS checked_rows FROM _ai_json_rows GROUP BY table_name ORDER BY table_name;',
        'COMMIT;' if commit else 'ROLLBACK;',
    ]
    return '\n'.join(statements) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--expand', action='store_true', help='Losslessly package explicit source rows as ordinary JSON objects')
    mode.add_argument('--check', action='store_true', help='Validate JSON offline without database access (default)')
    mode.add_argument('--dry-run', action='store_true', help='Test import against local DB, then roll back')
    mode.add_argument('--import', dest='apply', action='store_true', help='Append JSON data to local Supabase')
    args = parser.parse_args()
    expanded = expand()
    counts = validate(expanded)
    if args.expand:
        TARGET.write_text(json.dumps(expanded, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
        print(f'Packaged explicit JSON values: {TARGET}')
    else:
        require(read_json(TARGET) == expanded, 'Object JSON differs from authored source; run npm run db:json:expand')
    print(json.dumps({'tables': counts, 'total_rows': sum(counts.values())}, indent=2))
    if not (args.dry_run or args.apply):
        print('Offline schema and relationship checks passed. Database constraints require --dry-run or --import.')
        return
    endpoint = subprocess.check_output(['docker', 'context', 'inspect', '--format', '{{.Endpoints.docker.Host}}'], text=True).strip()
    require(os.environ.get('DOCKER_HOST', endpoint).startswith('unix://'), 'A local Docker Unix socket is required')
    container = os.environ.get('SUPABASE_DB_CONTAINER', 'supabase_db_db')
    subprocess.run(['docker', 'exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-f', '/dev/stdin'],
                   input=import_sql(expanded, args.apply), text=True, check=True)
    print('JSON import committed.' if args.apply else 'Database constraint checks passed; import rolled back. Sequences may have advanced.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        print(f'JSON check/import failed: {error}', file=sys.stderr)
        sys.exit(1)
