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
    OLD_STATE_COUNT_NEEDED = 5
    NEW_STATE_COUNT_NEEDED = 5
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


class TestCheckpointCreationFailure:
    def fail_create_checkpoint(self, st_checkpoint=None):
        """ Start test dir with a checkpoint, if provided, make changes to
        test dir and try to fail checkpointing of the changes.
        """
        # reset test directory
        if st_checkpoint:
            TestHelpers.reset_test_dir(TestMetadata.TEST_DIR,
                                       TestMetadata.CP_OLD)
            checkpoint.create_checkpoint(TestMetadata.TEST_DIR)
        else:
            TestHelpers.reset_test_dir(TestMetadata.TEST_DIR)

        # initialize checkpoint creation executor and killer
        exec_kill = ExecAndKill(TestMetadata.SLEEP_INCREMENT,
                                checkpoint.create_checkpoint,
                                TestMetadata.TEST_DIR)

        # run the tests
        old_state = new_state = 0
        for _ in range(TestMetadata.REP_LIMITS):

            if new_state >= TestMetadata.NEW_STATE_COUNT_NEEDED:
                break

            # make changes to test dir
            TestHelpers.reset_test_dir(TestMetadata.TEST_DIR,
                                       TestMetadata.CP_NEW)

            # create checkpoint with failure
            exec_kill.exec_and_kill_once()

            # restore from checkpoint
            checkpoint.restore_checkpoint(TestMetadata.TEST_DIR)

            # match with old and new states
            if st_checkpoint:
                match_old = TestHelpers.match_dir_contents(
                    TestMetadata.CP_OLD, TestMetadata.TEST_DIR, '.')
            else:
                match_old = TestHelpers.is_dir_empty(TestMetadata.TEST_DIR)
            match_new = TestHelpers.match_dir_contents(TestMetadata.CP_NEW,
                                                       TestMetadata.TEST_DIR,
                                                       '.')

            # match one of the checkpointed states
            assert match_old ^ match_new, "Inconsistent state detected. Only \
                hidden files are ignored to omit filesystem specific files \
                like .DS_Store"

            # count of new checkpointed state was restored
            if match_new:
                new_state += 1
            else:
                old_state += 1

        # old checkpoint was not overwritten completely and restored expected
        # number of times
        assert old_state >= TestMetadata.OLD_STATE_COUNT_NEEDED, \
            "Old state not seen enough times. Consider checking again with lower \
                TestMetadata.SLEEP_INCREMENT"

        # new checkpoint was successfully created and restored expected number
        # of times
        assert new_state >= TestMetadata.NEW_STATE_COUNT_NEEDED, \
            "Repetition limit exceeded. Consider checking again with higher \
                TestMetadata.SLEEP_INCREMENT or TestMetadata.REP_LIMITS"

        # clear checkpoint
        checkpoint.clear_checkpoint(TestMetadata.TEST_DIR)

    # covers creation first
    def test_failure_creating_first_checkpoint(self):
        self.fail_create_checkpoint()

    # covers creation new
    def test_failure_creating_new_checkpoint(self):
        self.fail_create_checkpoint(TestMetadata.CP_OLD)


class TestCheckpointRestorationFailure:
    pass


class TestCheckpointClearanceFailure:
    pass
