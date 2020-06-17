import checkpoint
import filecmp
import os
import shutil

""" Testing strategy

Partition checkpoint manipulation as follows:
- creation      first, multiple
- restore       empty dir, non-empty dir
- clear         once, multiple

Exhausitve Cartesian coverage of partitions with restore.
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


class TestHelpers:
    @staticmethod
    def reset_test_dir():
        shutil.rmtree(TestMetadata.TEST_DIR)
        shutil.copytree(TestMetadata.MATCH_DIR, TestMetadata.TEST_DIR)

    @staticmethod
    def match_dir_contents(n):
        """ Ensure all directories and all files in MATCH_DIR are in TEST_DIR.
        """
        for subdir, dirs, files in os.walk(
                os.path.join(TestMetadata.MATCH_DIR, TestMetadata.TESTS[n])):

            # match all directories in this subdirectory
            for d in dirs:
                assert os.path.isdir(os.path.join(subdir, d)
                                     .replace(TestMetadata.MATCH_DIR,
                                              TestMetadata.TEST_DIR))

            # match all files
            for f in files:
                path_match = os.path.join(subdir, f)
                path_test = path_match.replace(TestMetadata.MATCH_DIR,
                                               TestMetadata.TEST_DIR)

                # check file exists
                assert os.path.isfile(path_test)

                # check contents are same
                assert filecmp.cmp(
                    path_test, path_match, shallow=False)

    @staticmethod
    def is_dir_empty(n):
        return [] == os.listdir(os.path.join(TestMetadata.MATCH_DIR,
                                             TestMetadata.TESTS[n]))


class TestCheckpointCreation:
    def create_restore(self, reps=1, empty=False):
        """ Create checkpoint and then restore from checkpoint. """
        TestHelpers.reset_test_dir()
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

            TestHelpers.match_dir_contents(i)

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
        TestHelpers.reset_test_dir()
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
            TestHelpers.is_dir_empty(i)

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
