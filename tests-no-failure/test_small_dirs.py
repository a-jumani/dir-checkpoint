from tests_helpers.helpers import TestHelpers
import checkpoint
import os
import shutil

""" Testing strategy

Partition checkpoint manipulation as follows:
- creation      first, multiple
- restore       empty dir, non-empty dir
- clear         once, multiple

Exhaustive Cartesian coverage of partitions with restore.
"""


class TestMetadata:
    # constant directory
    MATCH_DIR = os.path.join('tests-no-failure', 'match-dirs')

    # directory for testing checkpointing
    TEST_DIR = os.path.join('tests-no-failure', 'test-dirs')

    # individual tests
    TESTS = {
        0: 'test0-1file',
        1: 'test1-1dir1file',
        2: 'test2-1dir2file',
        3: 'test3-2dir0file2file',
        4: 'test4-0file',
    }


class TestCheckpointCreation:
    def create_restore(self, reps=1, empty=False):
        """ Create checkpoint and then restore from checkpoint. """
        TestHelpers.reset_test_dir(TestMetadata.TEST_DIR,
                                   TestMetadata.MATCH_DIR)
        for i in TestMetadata.TESTS:
            dir_path = os.path.join(TestMetadata.TEST_DIR,
                                    TestMetadata.TESTS[i])

            # create checkpoint(s)
            for _ in range(reps):
                checkpoint.create_checkpoint(dir_path)

            # empty dir
            if empty:
                shutil.rmtree(dir_path)
                os.mkdir(dir_path)

            # restore from checkpoint
            checkpoint.restore_checkpoint(dir_path)

            # test contents
            content_match, match_error = TestHelpers.is_dir_contents_same(
                TestMetadata.MATCH_DIR,
                TestMetadata.TEST_DIR,
                TestMetadata.TESTS[i]
            )
            assert content_match, match_error

    # covers creation first
    #        restore  non-empty dir
    def test_create_restore(self):
        self.create_restore()

    # covers creation multiple
    #        restore  non-empty dir
    def test_create_restore_multiple(self):
        self.create_restore(2)
        self.create_restore(4)
        self.create_restore(5)

    # covers creation first
    #        restore  empty dir
    def test_create_empty_restore(self):
        self.create_restore(empty=True)

    # covers creation multiple
    #        restore  empty dir
    def test_create_empty_restore_multiple(self):
        self.create_restore(2, True)
        self.create_restore(3, True)


class TestCheckpointClearance:
    def clear_restore(self, reps=1, empty=False):
        TestHelpers.reset_test_dir(TestMetadata.TEST_DIR,
                                   TestMetadata.MATCH_DIR)
        for i in TestMetadata.TESTS:
            dir_path = os.path.join(TestMetadata.TEST_DIR,
                                    TestMetadata.TESTS[i])

            # create checkpoint
            checkpoint.create_checkpoint(dir_path)

            # clear checkpoint
            for _ in range(reps):
                checkpoint.clear_checkpoint(dir_path)

            # empty dir
            if empty:
                shutil.rmtree(dir_path)
                os.mkdir(dir_path)

            # restore from checkpoint
            checkpoint.restore_checkpoint(dir_path)

            # check dir is empty
            content_match, match_error = TestHelpers.is_dir_empty(
                TestMetadata.TEST_DIR,
                TestMetadata.TESTS[i]
            )
            assert content_match, match_error

    # covers clear    once
    #        restore  non-empty dir
    def test_create_clear_restore(self):
        self.clear_restore()

    # covers clear    multiple
    #        restore  non-empty dir
    def test_create_clear_restore_multiple(self):
        self.clear_restore(2)
        self.clear_restore(4)
        self.clear_restore(5)

    # covers clear    one
    #        restore  empty dir
    def test_create_clear_empty_restore(self):
        self.clear_restore(empty=True)

    # covers clear    multiple
    #        restore  empty dir
    def test_create_clear_empty_restore_multiple(self):
        self.clear_restore(2, True)
        self.clear_restore(3, True)
