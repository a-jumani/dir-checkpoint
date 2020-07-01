# dir-checkpoint
Create and manage fault-tolerant checkpointing for a directory.

__Guarantee:__ a successful call to `restore_checkpoint(path)` restores `path` to the latest checkpointed state (i.e. most recent _successful_ call to `create_checkpoint` or `clear_checkpoint`). The implementation depends on the following assumptions:
- `os.rename` is atomic, and
- if `os.rename` on a directory is successful, directory data is successfully persisted.

__Test Status (1 Jul 2020):__ fault tolerance tests passed with 100% coverage.

Note: tested using python 3.7 on macOS 10.15.

## Usage
Check `checkpoint.py` for documentation.

## Testing
Using `pip install -r requirements.txt` to install required libraries / modules. Run tests from `dir-checkpoint/` using:
- (no coverage, no fault tolerance): `PYTHONPATH=. pytest tests-no-failure/`
- (coverage, no fault tolerance): `PYTHONPATH=. pytest [--cov-report term-missing] --cov=checkpoint tests-no-failure/` 
- (no coverage, fault tolerance): `PYTHONPATH=. pytest tests-failure/`
- (coverage, fault tolerance): `PYTHONPATH=. pytest [--cov-report term-missing] --cov=checkpoint tests-failure/`

#### Note on Fault Tolerance Tests
Fault tolerance tests check for consistency in face of failures, i.e.
- test directory is either in the old state (e.g. identical to a checkpoint) if an API call fails, or
- in the new state (e.g. empty as checkpoint was cleared) if the API call succeeds,
- but never in any other state.

These tests execute an API call in another process and kill (using `SIGKILL`) that process after some time to simulate failure. The time interval between creation and killing of the process keeps increasing by `TestMetadata.SLEEP_INCREMENT` until:
- **Success:** we have seen test directory in the old state (i.e. due to failed API call) and in new state (i.e. due to API call succeeding). We also want to see the old state and new state at least `TestMetadata.SUCCESS_COUNT_NEEDED` times.
- **Failure:** test directory is neither in old state nor in new state after a successful restore (i.e. inconsistent state), or test repetitions (controlled by `TestMetadata.REP_LIMITS`) have been exhausted.

It is apparent that test failure can also result from `TestMetadata.SLEEP_INCREMENT * TestMetadata.REP_LIMITS` being
- too low so that the API call never succeeds, or
- too high resulting in API call always succeeding.

Hence, these parameters may need tweaking according to the performance of your testing system.
