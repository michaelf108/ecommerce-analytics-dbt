"""Export the dbt marts from DuckDB so Power BI can load the modelled star schema.

Power BI Desktop cannot read ``olist.duckdb`` directly, and the database is
gitignored anyway, so this script copies the finished marts out to flat files
that Power BI loads with Get Data. Run it after ``uv run dbt build``.

    uv run python powerbi/export_marts.py            # Parquet (default)
    uv run python powerbi/export_marts.py --format csv
    uv run python powerbi/export_marts.py --format both

Parquet is the default because it keeps the column types Power BI needs without
any Power Query clean-up: timestamps stay timestamps (the delivery and
seasonality visuals depend on this), money stays decimal, and the surrogate
keys and zip-code prefixes stay text so the relationships do not silently break
on a number that drops its leading zeros.

Tables exported (marts only, never staging or intermediate):

    Core star schema
        dim_customers       one row per customer_id   (customer_key)
        dim_products        one row per product_id    (product_key)
        dim_sellers         one row per seller_id      (seller_key)
        fct_orders          one row per order          (order_key)
        fct_order_items     one row per order line      (order_item_key)

    Aggregate marts (pre-built for the dashboard pages)
        customer_rfm        one row per customer_unique_id (the real person)
        seller_performance  one row per seller

Relationships to draw in the Power BI model view (all single-direction, one to
many from the dimension to the fact):

    dim_customers[customer_key]   1 -> *  fct_orders[customer_key]
    dim_products[product_key]     1 -> *  fct_order_items[product_key]
    dim_sellers[seller_key]       1 -> *  fct_order_items[seller_key]
    fct_orders[order_id]          1 -> *  fct_order_items[order_id]

order_id is a degenerate dimension: it lives in the facts and bridges the two
fact grains (one order, many lines), which lets the line-grain facts inherit
the customer through fct_orders. seller_performance joins to dim_sellers on
seller_key (one to one); customer_rfm is keyed on customer_unique_id and is
best used as a standalone table on the Customer Intelligence page, since one
person can hold several customer_id values.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parent.parent

# Marts to export, in load order. Dimensions first so Power BI offers them as
# the "one" side when it auto-detects relationships.
MARTS = [
    "dim_customers",
    "dim_products",
    "dim_sellers",
    "fct_orders",
    "fct_order_items",
    "customer_rfm",
    "customer_satisfaction",
    "category_satisfaction",
    "seller_performance",
]


def export_table(con: duckdb.DuckDBPyConnection, table: str, out_dir: Path, fmt: str) -> None:
    """Copy a single mart to <out_dir>/<table>.<fmt>."""
    if fmt == "parquet":
        target = out_dir / f"{table}.parquet"
        copy_opts = "(FORMAT PARQUET)"
    elif fmt == "csv":
        target = out_dir / f"{table}.csv"
        copy_opts = "(FORMAT CSV, HEADER)"
    else:
        raise ValueError(f"unsupported format: {fmt}")

    # forward slashes so the path is safe inside the SQL string on Windows
    target_sql = target.as_posix()
    con.execute(f'COPY (SELECT * FROM main."{table}") TO \'{target_sql}\' {copy_opts}')

    rows = con.execute(f'SELECT count(*) FROM main."{table}"').fetchone()[0]
    print(f"  {rows:>9,}  {target.relative_to(REPO_ROOT).as_posix()}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        choices=["parquet", "csv", "both"],
        default="parquet",
        help="output format (default: parquet)",
    )
    parser.add_argument(
        "--db",
        default=str(REPO_ROOT / "olist.duckdb"),
        help="path to the DuckDB database (default: ./olist.duckdb)",
    )
    parser.add_argument(
        "--out",
        default=str(REPO_ROOT / "powerbi" / "exports"),
        help="output directory (default: ./powerbi/exports)",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"database not found: {db_path}\nRun `uv run dbt build` first.")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    formats = ["parquet", "csv"] if args.format == "both" else [args.format]

    con = duckdb.connect(str(db_path), read_only=True)
    try:
        for fmt in formats:
            print(f"Exporting {len(MARTS)} marts to {fmt} in {out_dir.relative_to(REPO_ROOT).as_posix()}/")
            for table in MARTS:
                export_table(con, table, out_dir, fmt)
    finally:
        con.close()

    print("Done. Load these files in Power BI with Get Data, then draw the")
    print("relationships listed in the module docstring at the top of this file.")


if __name__ == "__main__":
    main()
