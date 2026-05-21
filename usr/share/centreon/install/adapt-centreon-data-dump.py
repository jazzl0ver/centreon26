#!/usr/bin/env python3
import argparse
import os
import re
import subprocess
import sys

SCHEMAS = {
    "config": ["usr/share/centreon/www/install/createTables.sql"],
    "storage": [
        "usr/share/centreon/www/install/createTablesCentstorage.sql",
        "usr/share/centreon/www/install/installBroker.sql",
    ],
    "status": ["usr/share/centreon/www/install/createNDODB.sql"],
}


def read_file(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def read_git(ref, path):
    return subprocess.check_output(
        ["git", "show", "%s:%s" % (ref, path)],
        text=True,
        stderr=subprocess.DEVNULL,
    )


def statements(sql):
    buf, quote, esc = [], None, False
    for ch in sql:
        buf.append(ch)
        if quote:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                quote = None
        else:
            if ch in ("'", '"', "`"):
                quote = ch
            elif ch == ";":
                stmt = "".join(buf).strip()
                if stmt:
                    yield stmt
                buf = []
    tail = "".join(buf).strip()
    if tail:
        yield tail


def csv_top(s):
    out, start, quote, esc, depth = [], 0, None, False, 0
    for i, ch in enumerate(s):
        if quote:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                quote = None
        else:
            if ch in ("'", '"', "`"):
                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif ch == "," and depth == 0:
                out.append(s[start:i].strip())
                start = i + 1
    out.append(s[start:].strip())
    return out


def rows(values):
    out, start, quote, esc, depth = [], None, None, False, 0
    for i, ch in enumerate(values):
        if quote:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                quote = None
        else:
            if ch in ("'", '"'):
                quote = ch
            elif ch == "(":
                if depth == 0:
                    start = i + 1
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0 and start is not None:
                    out.append(values[start:i].strip())
    return out


def q(name):
    return "`" + name.replace("`", "``") + "`"


def unq(name):
    name = name.strip()
    if name.startswith("`") and name.endswith("`"):
        return name[1:-1].replace("``", "`")
    return name


def table_columns(create_sql):
    schema = {}
    for stmt in statements(create_sql):
        m = re.search(
            r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"
            r"(?:(`(?:``|[^`])+`|[A-Za-z0-9_$]+)\.)?"
            r"(`(?:``|[^`])+`|[A-Za-z0-9_$]+)\s*\((.*)\)",
            stmt,
            re.I | re.S,
        )
        if not m:
            continue
        table, body = unq(m.group(2)), m.group(3)
        cols = []
        for item in csv_top(body):
            item = item.strip()
            col = re.match(r"^(`(?:``|[^`])+`|[A-Za-z_][A-Za-z0-9_$]*)\s+", item)
            if not col:
                continue
            raw_col = col.group(1)
            if not raw_col.startswith("`") and unq(raw_col).upper() in (
                "PRIMARY",
                "UNIQUE",
                "KEY",
                "INDEX",
                "CONSTRAINT",
                "FULLTEXT",
                "SPATIAL",
                "FOREIGN",
                "CHECK",
            ):
                continue
            cols.append(unq(raw_col))
        schema[table] = cols
    return schema


def load_schema(ref, schema_files=None):
    loaded = {}
    for role, paths in SCHEMAS.items():
        loaded[role] = {}
        schema_paths = schema_files.get(role) if schema_files else None
        for path in schema_paths or paths:
            if schema_paths:
                sql = read_file(path)
            elif ref:
                try:
                    sql = read_git(ref, path)
                except subprocess.CalledProcessError:
                    raise SystemExit("cannot read old schema %s from %s" % (path, ref))
            else:
                sql = read_file(path)
            loaded[role].update(table_columns(sql))
    return loaded


def parse_db_list(value):
    return [x.strip() for x in value.split(",") if x.strip()]


def parse_path_list(value):
    return [x.strip() for x in value.split(",") if x.strip()] if value else []


def ident_key(name):
    return name.lower()


def table_index(schema):
    return {
        role: {ident_key(table): table for table in tables}
        for role, tables in schema.items()
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump", help="mysqldump -t data dump, or - for stdin")
    ap.add_argument("--old-ref", default="HEAD", help="git ref with old schema files")
    ap.add_argument(
        "--old-schema-dir",
        help="directory with centreon.schema.sql, centreon_storage.schema.sql, centreon_status.schema.sql",
    )
    ap.add_argument("--old-config-schema-file")
    ap.add_argument("--old-storage-schema-file")
    ap.add_argument("--old-status-schema-file")
    ap.add_argument("--config-db", default="centreon")
    ap.add_argument("--storage-db", default="centreon_storage")
    ap.add_argument("--status-db", default="centreon_status")
    ap.add_argument("--old-config-db", default="centreon")
    ap.add_argument("--old-storage-db", default="centreon_storage,centstorage")
    ap.add_argument("--old-status-db", default="centreon_status,ndo")
    ap.add_argument(
        "--source-schema",
        choices=["config", "storage", "status"],
        help="schema of this dump when it has no USE and no db-qualified INSERTs",
    )
    ap.add_argument(
        "--source-db",
        help="old database name of this dump when it has no USE and no db-qualified INSERTs",
    )
    ap.add_argument("--insert-mode", choices=["insert", "insert-ignore", "replace"], default="insert")
    ap.add_argument(
        "--extra-values",
        choices=["skip", "drop-trailing"],
        default="skip",
        help="what to do when a row has more values than the old schema has columns",
    )
    args = ap.parse_args()

    old_schema_files = {}
    if args.old_schema_dir:
        old_schema_files = {
            "config": [os.path.join(args.old_schema_dir, "centreon.schema.sql")],
            "storage": [os.path.join(args.old_schema_dir, "centreon_storage.schema.sql")],
            "status": [os.path.join(args.old_schema_dir, "centreon_status.schema.sql")],
        }
    if args.old_config_schema_file:
        old_schema_files["config"] = parse_path_list(args.old_config_schema_file)
    if args.old_storage_schema_file:
        old_schema_files["storage"] = parse_path_list(args.old_storage_schema_file)
    if args.old_status_schema_file:
        old_schema_files["status"] = parse_path_list(args.old_status_schema_file)

    old_schema = load_schema(args.old_ref, old_schema_files)
    new_schema = load_schema(None)
    old_table_index = table_index(old_schema)
    new_table_index = table_index(new_schema)
    new_db = {"config": args.config_db, "storage": args.storage_db, "status": args.status_db}

    db_role = {}
    for db in parse_db_list(args.old_config_db) + [args.config_db]:
        db_role[ident_key(db)] = "config"
    for db in parse_db_list(args.old_storage_db) + [args.storage_db]:
        db_role[ident_key(db)] = "storage"
    for db in parse_db_list(args.old_status_db) + [args.status_db]:
        db_role[ident_key(db)] = "status"

    source_role = args.source_schema
    if args.source_db:
        source_db_role = db_role.get(ident_key(args.source_db))
        if not source_db_role:
            raise SystemExit("unknown --source-db: %s" % args.source_db)
        if source_role and source_role != source_db_role:
            raise SystemExit("--source-schema conflicts with --source-db")
        source_role = source_db_role

    table_roles = {}
    for role, schema in old_schema.items():
        for table in schema:
            table_roles.setdefault(ident_key(table), []).append(role)

    sql = sys.stdin.read() if args.dump == "-" else read_file(args.dump)
    current_db = None

    print("SET FOREIGN_KEY_CHECKS=0;")
    print("SET UNIQUE_CHECKS=0;")
    print("SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';")
    print("SET NAMES utf8;")

    for stmt in statements(sql):
        clean = stmt.strip()
        m = re.match(r"USE\s+`?([^`;]+)`?", clean, re.I)
        if m:
            current_db = m.group(1)
            continue
        if not re.match(r"^(INSERT|REPLACE)\s", clean, re.I):
            continue

        m = re.match(
            r"^(INSERT(?:\s+IGNORE)?|REPLACE)\s+INTO\s+"
            r"(?:(`(?:``|[^`])+`|[A-Za-z0-9_$]+)\.)?"
            r"(`(?:``|[^`])+`|[A-Za-z0-9_$]+)\s*"
            r"(?:\((.*?)\))?\s+VALUES\s*(.*);?$",
            clean,
            re.I | re.S,
        )
        if not m:
            print("skip: cannot parse INSERT", file=sys.stderr)
            continue

        _verb, src_db, table, explicit_cols, value_sql = m.groups()
        src_db = unq(src_db) if src_db else None
        table = unq(table)
        table_key = ident_key(table)
        current_db_key = ident_key(src_db or current_db) if src_db or current_db else None
        role = db_role.get(current_db_key) if current_db_key else None
        if not role and source_role:
            role = source_role
        old_table = old_table_index.get(role, {}).get(table_key) if role else None
        new_table = new_table_index.get(role, {}).get(table_key) if role else None
        if not role or not old_table or not new_table:
            candidates = [
                candidate
                for candidate in table_roles.get(table_key, [])
                if table_key in new_table_index[candidate]
            ]
            role = candidates[0] if len(candidates) == 1 else None
            if len(candidates) > 1:
                print(
                    "skip: ambiguous table without source schema: %s (%s)"
                    % (table, ", ".join(candidates)),
                    file=sys.stderr,
                )
                continue
            old_table = old_table_index.get(role, {}).get(table_key) if role else None
            new_table = new_table_index.get(role, {}).get(table_key) if role else None
        if not role or not old_table or not new_table:
            print("skip: table not in schema: %s" % table, file=sys.stderr)
            continue

        src_cols = [unq(c) for c in csv_top(explicit_cols)] if explicit_cols else old_schema[role][old_table]
        parsed_rows, ok = [], True
        actual_len = None
        for row in rows(value_sql):
            vals = csv_top(row)
            if actual_len is None:
                actual_len = len(vals)
            elif len(vals) != actual_len:
                print(
                    "skip: mixed value counts in %s: got %d and %d"
                    % (table, actual_len, len(vals)),
                    file=sys.stderr,
                )
                ok = False
                break
            parsed_rows.append(vals)
        if not ok or not parsed_rows:
            continue

        if actual_len != len(src_cols):
            if explicit_cols:
                print(
                    "skip: value count mismatch in %s: got %d, expected %d"
                    % (table, actual_len, len(src_cols)),
                    file=sys.stderr,
                )
                continue
            if actual_len > len(src_cols):
                if args.extra_values != "drop-trailing":
                    print(
                        "skip: value count mismatch in %s: got %d, expected %d"
                        % (table, actual_len, len(src_cols)),
                        file=sys.stderr,
                    )
                    continue
                print(
                    "warn: long row in %s: got %d, expected %d; dropping trailing %d values"
                    % (table, actual_len, len(src_cols), actual_len - len(src_cols)),
                    file=sys.stderr,
                )
                parsed_rows = [vals[:len(src_cols)] for vals in parsed_rows]
                actual_len = len(src_cols)
            else:
                print(
                    "warn: short row in %s: got %d, expected %d; assuming first %d old columns"
                    % (table, actual_len, len(src_cols), actual_len),
                    file=sys.stderr,
                )
                src_cols = src_cols[:actual_len]

        dst_cols = new_schema[role][new_table]
        pos = {ident_key(col): i for i, col in enumerate(src_cols)}
        keep = [col for col in dst_cols if ident_key(col) in pos]
        keep_pos = [pos[ident_key(col)] for col in keep]
        if not keep:
            print("skip: no common columns: %s" % table, file=sys.stderr)
            continue

        out_rows = ["(" + ", ".join(vals[i] for i in keep_pos) + ")" for vals in parsed_rows]

        verb = {"insert": "INSERT", "insert-ignore": "INSERT IGNORE", "replace": "REPLACE"}[args.insert_mode]
        print("\n%s INTO %s.%s (%s) VALUES" % (
            verb,
            q(new_db[role]),
            q(new_table),
            ", ".join(q(c) for c in keep),
        ))
        print(",\n".join(out_rows) + ";")

    print("\nSET UNIQUE_CHECKS=1;")
    print("SET FOREIGN_KEY_CHECKS=1;")


if __name__ == "__main__":
    main()
