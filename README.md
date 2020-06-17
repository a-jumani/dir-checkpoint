# dir-checkpoint
Create and manage fault-tolerant checkpointing for a directory. Uses atomicity of `os.rename` to implement the functionality.

Note: tested using python 3.7 on macOS 10.15.

## Usage
Check `checkpoint.py` for documentation.

## Testing
Using `pip install -r requirements.txt` to install required libraries / modules. Run tests from `dir-checkpoint/` using:
- (no coverage, no fault tolerance): `PYTHONPATH=. pytest tests-no-failure/`
- (coverage, no fault tolerance): `PYTHONPATH=. pytest --cov=checkpoint tests-no-failure/` 
- (no coverage, fault tolerance): `./tests-failure/tests.sh 0 || set -m`.
