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
    def is_dir_contents_same(match_dir, test_dir, test_folder):
        """ Check all directories and all files within match_dir/test_folder
        are also in test_dir/test_folder.
        """
        for subdir, dirs, files in os.walk(
                os.path.join(match_dir, test_folder)):

            # match all directories in this subdirectory
            for d in dirs:
                find_dir = os.path.join(subdir, d).replace(match_dir, test_dir)
                dir_exists = os.path.isdir(find_dir)
                if not dir_exists:
                    return (False, "Directory {} not found".format(find_dir))

            # match all files
            for f in files:

                # ignore hidden files - to ignore files like .DS_Store
                if f.startswith('.'):
                    continue

                path_match = os.path.join(subdir, f)
                path_test = path_match.replace(match_dir, test_dir)

                # check file exists contents are the same
                if os.path.isfile(path_test):
                    if not filecmp.cmp(path_test, path_match, shallow=False):
                        return (False, "Content differs {}".format(path_test))
                else:
                    return (False, "File {} not found".format(path_test))

        return (True, "")

    @staticmethod
    def is_dir_contents_diff(match_dir, test_dir, test_folder):
        """ Check if directory contents are different in match_dir/test_folder
        and test_dir/test_folder.
        """
        if TestHelpers.is_dir_contents_same(match_dir, test_dir,
                                            test_folder)[0]:
            return (False, "Same content in both directories")
        return (True, "")

    @staticmethod
    def is_dir_empty(*path_portions):
        """ Check if directory pointed to by path_portions is empty.
        """
        contents = os.listdir(os.path.join(*path_portions))
        return ([] == contents, "Directory contains {}".format(contents))
