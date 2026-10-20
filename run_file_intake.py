"""Entry point: file intake. Gets files in inbound/landed/ ready for the pipeline. Separate from the pipeline run.

    python run_file_intake.py            # take in everything in inbound/landed/ now
    python run_file_intake.py --serve    # take in new files every 5 minutes

Each file gets a file_id and an ingestion log row, then moves to inbound/<source_name>/<YYYY-MM-DD>/
(status 'arrived', ready for bronze) or inbound/unmatched/<YYYY-MM-DD>/ (status 'unmatched').
See 01_ingestion/intake_files.py.
"""
import argparse
import importlib

intake = importlib.import_module("01_ingestion.intake_files")  # folder names start with a digit


def main() -> None:
    parser = argparse.ArgumentParser(description="Move files from inbound/landed/ to their source folders.")
    parser.add_argument("--serve", action="store_true", help="run every 5 minutes")
    args = parser.parse_args()
    if args.serve:
        intake.intake_files.serve(name="intake-files-every-5-min", cron="*/5 * * * *")
    else:
        intake.intake_files()


if __name__ == "__main__":
    main()
