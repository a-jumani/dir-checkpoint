import filecmp
import os
import shutil


class TestHelpers:
    @staticmethod
    def reset_test_dir(test_dir, cp_dir=''):
        """ Set test_dir to empty dir or copy of cp_dir.
        """
        if os.path.isdir(test_dir):
            shutil.rmtree(test_dir)
        shutil.copytree(cp_dir, test_dir) if cp_dir else os.mkdir(test_dir)

    @staticmethod
    def match_dir_contents(match_dir, test_dir, test_folder):
        """ Check all directories and all files within match_dir/test_folder
        are also in test_dir/test_folder.
        """
        result = True

        for subdir, dirs, files in os.walk(
                os.path.join(match_dir, test_folder)):

            # match all directories in this subdirectory
            result &= all(os.path.isdir(os.path.join(subdir, d)
                                        .replace(match_dir, test_dir))
                          for d in dirs)

            # match all files
            for f in files:

                # ignore hidden files - to ignore files like .DS_Store
                if f.startswith('.'):
                    continue

                path_match = os.path.join(subdir, f)
                path_test = path_match.replace(match_dir, test_dir)

                # check file exists contents are the same
                file_exists = os.path.isfile(path_test)
                if file_exists:
                    result &= filecmp.cmp(path_test, path_match, shallow=False)
                else:
                    result = False

        return result

    @staticmethod
    def is_dir_empty(*path_portions):
        """ Check if directory pointed to by path_portions is empty.
        """
        return [] == os.listdir(os.path.join(*path_portions))
