from multiprocessing import Process
from signal import SIGKILL
from tests_helpers.helpers import TestHelpers
from time import sleep
import checkpoint
import os

""" Testing strategy

Definitions:
    DIR: directory checkpointed
    OLD_CP: old checkpoint (match-old-cp/)
    NEW_CP: new checkpoint (match-new-cp/)

Partition failure as follows:
- creation      first, new
- restore       checkpoint exists
- clear         checkpoint exists

Exhausitve coverage of partitions.
"""


class TestMetadata:
    FOLDER = "tests-failure"
    CP_OLD = os.path.join(FOLDER, "match-old-cp")
    CP_NEW = os.path.join(FOLDER, "match-new-cp")
    TEST_DIR = os.path.join(FOLDER, "test-cp")
    SLEEP_INCREMENT = 0.001
    SUCCESS_COUNT_NEEDED = 5
    REP_LIMITS = 200


class ExecAndKill(object):

    def __init__(self, sleep_increment, func, *args):
        self.sleep = 0
        self.sleep_increment = sleep_increment
        self.func = func
        self.args = args

    def exec_and_kill_once(self):
        # increment sleep counter
        self.sleep += self.sleep_increment

        # launch process
        p = Process(target=self.func, args=self.args)
        p.start()

        # sleep specified amount
        sleep(self.sleep)

        # kill process once pid is available
        while not p.pid:
            continue
        try:
            os.kill(p.pid, SIGKILL)
        except ProcessLookupError:
            pass

    def reset(self):
        self.sleep = 0


def fail_checkpoint_func(func, starting_cp, change_test, reset_test_to,
                         restore_cp, old_state_spec, new_state_spec):
    """ Start test dir with a checkpoint, if provided, make changes to
    test dir and try to fail checkpointing of the changes.

    Args:
        func            function to fail while executing
        starting_cp     if not False (or equivalent), test directory starts as
                        a checkpointed copy of starting_cp; else its empty
        change_test     if not False (or equivalent), change test directory
                        after starting checkpoint creation once; only sensible
                        if starting_cp is set and reset_test_to is not set
        reset_test_to   if not None or "", test directory is made into a copy
                        of reset_test_to before func is called (and failed)
        restore_cp      if True, test dir is restored before below state specs
                        are measured
        old_state_spec  (callable, args, str) where callable(*args) is used to
                        detect old state and str is old state's name
        new_state_spec  (callable, args, str) where callable(*args) is used to
                        detect new state and str is new state's name
    """
    # test dir starting point
    if starting_cp:
        TestHelpers.reset_test_dir(TestMetadata.TEST_DIR, starting_cp)
        checkpoint.create_checkpoint(TestMetadata.TEST_DIR)
    else:
        TestHelpers.reset_test_dir(TestMetadata.TEST_DIR)

    # initialize func executor and killer
    exec_kill = ExecAndKill(TestMetadata.SLEEP_INCREMENT,
                            func, TestMetadata.TEST_DIR)

    # change test dir once after starting checkpoint creation
    if change_test:
        TestHelpers.reset_test_dir(TestMetadata.TEST_DIR, change_test)

    # run the tests
    old_state = new_state = 0
    for _ in range(TestMetadata.REP_LIMITS):

        if new_state >= TestMetadata.SUCCESS_COUNT_NEEDED:
            break

        # make changes to test dir
        if reset_test_to:
            TestHelpers.reset_test_dir(TestMetadata.TEST_DIR, reset_test_to)

        # execute func with failure
        exec_kill.exec_and_kill_once()

        # restore from checkpoint
        if restore_cp:
            checkpoint.restore_checkpoint(TestMetadata.TEST_DIR)

        # match with old and new states
        match_old = old_state_spec[0](*old_state_spec[1])
        match_new = new_state_spec[0](*new_state_spec[1])

        # match exactly one of the states
        assert match_old[0] ^ match_new[0], "Inconsistent state detected. \
            Test dir should be an exact match with either {} or {}. Possible \
            errors: old state - {}, new state - {}.\
            \nNote: only hidden files are ignored to omit filesystem specific \
            files like .DS_Store in TestHelpers.is_dir_contents_same." \
            .format(old_state_spec[-1], new_state_spec[-1], match_old[1],
                    match_new[1])

        # count of new checkpointed state was restored
        if match_new[0]:
            new_state += 1
        else:
            old_state += 1

    # clear checkpoint
    checkpoint.clear_checkpoint(TestMetadata.TEST_DIR)

    # old state was not maintained expected number of times after failures
    assert old_state >= TestMetadata.SUCCESS_COUNT_NEEDED, \
        "Old state not maintained enough times. Consider checking \
            again with lower TestMetadata.SLEEP_INCREMENT."

    # new state was not found expected number of times after failures
    assert new_state >= TestMetadata.SUCCESS_COUNT_NEEDED, \
        "Repetition limit exceeded but new state wasn't matched enough \
            times. Consider checking again with higher \
            TestMetadata.SLEEP_INCREMENT or TestMetadata.REP_LIMITS."


class TestCheckpointCreationFailure:
    # covers creation       first
    def test_failure_creating_firstarting_cp(self):
        fail_checkpoint_func(
            func=checkpoint.create_checkpoint,
            starting_cp=None,
            change_test=None,
            reset_test_to=TestMetadata.CP_NEW,
            restore_cp=True,
            old_state_spec=(
                TestHelpers.is_dir_empty,
                (TestMetadata.TEST_DIR,),
                "an empty directory"
            ),
            new_state_spec=(
                TestHelpers.is_dir_contents_same,
                (TestMetadata.CP_NEW, TestMetadata.TEST_DIR, '.',),
                "TestMetadata.CP_NEW"
            ),
        )

    # covers creation       new
    def test_failure_creating_new_checkpoint(self):
        fail_checkpoint_func(
            func=checkpoint.create_checkpoint,
            starting_cp=TestMetadata.CP_OLD,
            change_test=None,
            reset_test_to=TestMetadata.CP_NEW,
            restore_cp=True,
            old_state_spec=(
                TestHelpers.is_dir_contents_same,
                (TestMetadata.CP_OLD, TestMetadata.TEST_DIR, '.',),
                "TestMetadata.CP_OLD",
            ),
            new_state_spec=(
                TestHelpers.is_dir_contents_same,
                (TestMetadata.CP_NEW, TestMetadata.TEST_DIR, '.',),
                "TestMetadata.CP_NEW",
            ),
        )


class TestCheckpointRestorationFailure:
    # covers restore        checkpoint exists
    def test_failure_restoring(self):
        fail_checkpoint_func(
            func=checkpoint.restore_checkpoint,
            starting_cp=TestMetadata.CP_OLD,
            change_test=TestMetadata.CP_NEW,
            reset_test_to=None,
            restore_cp=False,
            old_state_spec=(
                TestHelpers.is_dir_contents_diff,
                (TestMetadata.CP_OLD, TestMetadata.TEST_DIR, '.',),
                "different from TestMetadata.CP_OLD",
            ),
            new_state_spec=(
                TestHelpers.is_dir_contents_same,
                (TestMetadata.CP_OLD, TestMetadata.TEST_DIR, '.',),
                "TestMetadata.CP_OLD",
            ),
        )


class TestCheckpointClearanceFailure:
    # covers clear          checkpoint exists
    def test_failure_clearing(self):
        fail_checkpoint_func(
            func=checkpoint.clear_checkpoint,
            starting_cp=TestMetadata.CP_OLD,
            change_test=None,
            reset_test_to=TestMetadata.CP_OLD,
            restore_cp=True,
            old_state_spec=(
                TestHelpers.is_dir_contents_same,
                (TestMetadata.CP_OLD, TestMetadata.TEST_DIR, '.',),
                "TestMetadata.CP_OLD",
            ),
            new_state_spec=(
                TestHelpers.is_dir_empty,
                (TestMetadata.TEST_DIR,),
                "an empty directory"
            ),
        )
