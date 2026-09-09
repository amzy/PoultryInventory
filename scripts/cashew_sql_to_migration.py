#!/usr/bin/env python3
"""Convert a Cashew SQLite export into the JSON payload consumed by the app.

Usage:
  python3 scripts/cashew_sql_to_migration.py cashew-export.sql cashew-migration.json

The .sql extension is retained by Cashew, but the export is a SQLite database.
This script reads the category hierarchy and wallet/account directly from that
SQLite database, then applies the same explicit normalization used by the app.
Unknown categories are preserved instead of guessed.
"""
import json
import sqlite3
import sys
from datetime import datetime, timezone

MAPPINGS = {
    'layer feed': 'Feed',
    'stone': 'Grit',
    'health': 'Medical',
    'dr fee': 'Medical',
    'healthcare': 'Medical',
    'vaccine': 'Vaccine',
    'construction labor': 'Labor',
    'steel labor': 'Labor',
    'labor work': 'Labor',
    'construction materials': 'Materials',
    'material': 'Material',
}

def normalize(value):
    value = (value or '').strip()
    return MAPPINGS.get(value.lower(), value)

def date_from_epoch(value):
    return datetime.fromtimestamp(int(value), tz=timezone.utc).date().isoformat()

def main(src, dst):
    db = sqlite3.connect(src)
    db.row_factory = sqlite3.Row
    try:
        categories = {r['category_pk']: dict(r) for r in db.execute('select category_pk,name,main_category_pk,income from categories')}
        wallets = {r['wallet_pk']: r['name'] for r in db.execute('select wallet_pk,name from wallets')}
        records = []
        for t in db.execute('''
            select transaction_pk, name, amount, note, category_fk, sub_category_fk,
                   wallet_fk, date_created, income
            from transactions order by date_created
        '''):
            main = categories.get(t['category_fk'], {})
            sub = categories.get(t['sub_category_fk']) if t['sub_category_fk'] else None
            main_name = main.get('name') or 'Cashew'
            source_subcategory = (sub or {}).get('name') or main_name
            records.append({
                'transactionId': t['transaction_pk'],
                'date': date_from_epoch(t['date_created']),
                'mainCategory': main_name,
                'category': normalize(source_subcategory),
                'originalCategory': source_subcategory,
                'account': wallets.get(t['wallet_fk'], 'Unassigned'),
                'description': ' • '.join(x for x in [t['name'], t['note']] if x),
                'amount': float(t['amount']),
                'unit': 'rupees',
                'quantity': 0.0,
                'income': bool(t['income']),
                'transactionType': 'credit' if t['income'] else 'expense',
            })
        payload = {
            'source': 'Cashew',
            'formatVersion': 2,
            'exportedTransactions': len(records),
            'records': records,
        }
        with open(dst, 'w', encoding='utf-8') as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f'Wrote {len(records)} records to {dst}')
    finally:
        db.close()

if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: python3 scripts/cashew_sql_to_migration.py <cashew-export.sql> <migration.json>')
    main(sys.argv[1], sys.argv[2])
