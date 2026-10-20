"""Entry point: the pipeline run, as one Prefect flow. Run file intake (run_file_intake.py) first.

    python run_pipeline.py                  # bronze -> silver -> gold
    python run_pipeline.py --rerun 12       # same, re-loading file_id 12 into bronze
    python run_pipeline.py --serve          # run every 5 minutes

Each layer has one orchestrator at the top of its folder:
  1. 02_bronze/load_bronze.py   every file intake marked 'arrived', loaded as received
  2. 03_silver/load_silver.py   silver tables, company and person resolution, QC checks
  3. 04_gold/load_gold.py       published tables; tests block publication on failure
Every step only processes what is new, so a run with nothing new changes nothing (gold is rebuilt identically).
"""
import argparse
import importlib

from prefect import flow


def _layer(module: str):
    return importlib.import_module(module)  # layer folders start with a digit, so `import` syntax can't name them


bronze = _layer("02_bronze.load_bronze")
silver = _layer("03_silver.load_silver")
gold = _layer("04_gold.load_gold")


@flow(name="run-pipeline")
def run_pipeline(rerun_file_id: int | None = None) -> None:
    bronze.load_bronze(rerun_file_id=rerun_file_id)
    silver.load_silver()
    gold.load_gold()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the entity resolution pipeline.")
    parser.add_argument("--rerun", type=int, metavar="FILE_ID", help="re-load an existing file_id into bronze")
    parser.add_argument("--serve", action="store_true", help="run every 5 minutes")
    args = parser.parse_args()
    if args.serve:
        run_pipeline.serve(name="run-pipeline-every-5-min", cron="*/5 * * * *")
    else:
        run_pipeline(rerun_file_id=args.rerun)


if __name__ == "__main__":
    main()
