def create_checkpoint(path: str, empty: bool = False):
    """ Create copy of file(s) at path or an empty directory as a checkpoint.
    Atomic from the perspective of the caller.

    Args:
        path            path to a directory
        empty           if False, create copy of contents at path; otherwise
                        create empty checkpoint
    Preconditions:
        file(s) at path should not be changing while this function executes
    """
    pass


def restore_checkpoint(path: str):
    """ Restore file(s) at path from a checkpoint, if available. Atomic and
    idempotent from the perspective of the caller.

    Args:
        path            path to a directory
    """
    pass


def clear_checkpoint(path: str):
    """ Clear checkpoints of file(s) at path. Atomic and idempotent from the
    perspective of the caller.

    Args:
        path            path to a directory
    """
    pass
