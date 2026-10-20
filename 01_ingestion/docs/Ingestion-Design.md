# Ingestion Design

File intake: registers every arriving file, gives it a `file_id`, routes it by name, and moves it to its source folder, ready for bronze. It runs **separately from the pipeline run**. Back to [Pipeline Design](../../docs/design/Pipeline-Design.md).

| Code | Purpose |
|---|---|
| [intake_files.py](../intake_files.py) | **Orchestrator.** Prefect flow `intake-files`: takes in every file in `inbound/landed/`, oldest first |
| [move_and_register_landed_file.py](../functions/move_and_register_landed_file.py) | One file: reserve its `file_id`, route, move, then log |
| [match_file_name_to_pipeline.py](../functions/match_file_name_to_pipeline.py) | Finds the one pipeline whose file pattern matches a file name |
| [inbound_folder_paths.py](../functions/inbound_folder_paths.py) | The `inbound/` folder layout |

## Trigger

| Mode | How |
|---|---|
| On demand | `python run_file_intake.py`: takes in every file in `inbound/landed/` |
| Scheduled (production) | `python run_file_intake.py --serve`: every 5 minutes |

## Folders

```
inbound/
  landed/                                     files arrive here
  <source_name>/YYYY-MM-DD/{file_id}_{name}   routed, one folder per source (part1_company, salesforce)
  unmatched/YYYY-MM-DD/{file_id}_{name}       no pipeline configured for the file name
```

## Steps per file

Oldest file first:

1. **Reserve a `file_id`** from the log table's id sequence. No row is written yet.
2. **Route:** match the original file name against active `config.pipeline_file_pattern` rows. Exactly one pipeline must match.
3. **Move** the file to its final place, named `<file_id>_<name>`:
   - matched: `inbound/<source_name>/<date>/`;
   - unmatched: `inbound/unmatched/<date>/`.
4. **Log:** insert the row into `ingestion.file_ingestion_log`, with `file_path` pointing at the final location:
   - matched: status **`arrived`** (ready for bronze), with `pipeline_id`;
   - unmatched: status **`unmatched`**, with the reason.

The file is **moved first and logged second**, so a log row always points at where the file really is. If the insert fails after the move, the file is moved back to `landed/` and retried on the next run; the reserved `file_id` is simply never used (gaps in the id sequence are harmless). To take in an unmatched file once its pattern is configured, move it back into `inbound/landed/`.

Loading into bronze is the first step of the pipeline run: see [Bronze Design](../../02_bronze/docs/Bronze-Design.md).

## File identity

- **Every arrival is a new file** with its own `file_id`, regardless of name or content. A corrected file is a new file.
- The only reload is a **re-run of an existing `file_id`** (`python run_pipeline.py --rerun FILE_ID`). Its content is identical, so its `transaction_id`s are identical.

## Tables

**`ingestion.file_ingestion_log`**: one row per file, holding its **latest** state.

| Column | Description |
|---|---|
| `file_id` | Generated id (PK) |
| `pipeline_id` | Pipeline it routed to (blank if unmatched) |
| `original_file_name` | Name as received |
| `file_path` | Current location, relative to the project |
| `file_size` | Bytes |
| `row_count` | Data rows in the file. Empty after intake; filled in by the bronze load, the only step that reads the file |
| `arrival_time` | When it was registered |
| `status` | `arrived` (waiting for bronze) / `unmatched` / `loaded` / `failed` |
| `failure_reason` | Why it is unmatched or failed |
| `reload_attempts` | Number of re-runs |
| `last_attempt_at`, `loaded_at` | Latest attempt and latest successful load |

**`ingestion.file_ingestion_failure_log`**: one row per failed attempt (`file_id`, `attempt_number`, `failed_at`, `failure_reason`), so failure history is never overwritten.
