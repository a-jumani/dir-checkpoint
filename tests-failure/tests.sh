#!/usr/bin/env bash

FOLDER="tests-failure"
CP_OLD="${FOLDER}/match-old-cp"
CP_NEW="${FOLDER}/match-new-cp"
TEST_DIR="${FOLDER}/test-cp"
IGNORE_CHANGES=".DS_Store"      # format: <word1>|<word2>[...]

# replace test dir
replace_test_dir() {
    rm -rf $TEST_DIR
    cp -r $1 $TEST_DIR
}

# create old state w/ checkpoint
replace_test_dir $CP_OLD
python -c "import checkpoint; checkpoint.create_checkpoint('${TEST_DIR}')"

# TEST 1
echo "===================================================================="
echo "Test 1: Failure creating new checkpoint"
set +m

# counters
sleep_for=0
match_old_cp=0
match_new_cp=0

# repeat test until restore successfully picks up the new checkpoint
while [ $match_new_cp -lt 1 ]; do

    # update test dir
    replace_test_dir $CP_NEW

    # increase sleep amount by 0.001s
    sleep_for=$(echo "scale=2; ${sleep_for} + 0.001" | bc)

    # fail creation of new checkpoint after sleep_for time
    { python -c "import checkpoint; checkpoint.create_checkpoint('${TEST_DIR}')" & } 2> /dev/null
    sleep $sleep_for
    { kill $! %% && wait; } 2>/dev/null
    if [ $? -eq 0 ]; then
        printf "."
    fi

    # restore checkpoint
    rm -rf $TEST_DIR/*
    python -c "import checkpoint; checkpoint.restore_checkpoint('${TEST_DIR}')"

    # calculate number of diffs with checkpoints
    diff_old=$(diff -r $TEST_DIR $CP_OLD | grep -Ev \"$IGNORE_CHANGES\" | wc -l)
    diff_new=$(diff -r $TEST_DIR $CP_NEW | grep -Ev \"$IGNORE_CHANGES\" | wc -l)
    
    if [ $diff_old -gt 0 -a $diff_new -gt 0 ]; then
        echo "Test failed: restored checkpoint (${TEST_DIR}) is inconsistent."
        echo "Differences from old checkpoint (${CP_OLD}): ${diff_old}"
        echo "Differences from new checkpoint (${CP_NEW}): ${diff_new}"
        break
    fi

    if [ $diff_old -eq 0 ]; then
        match_old_cp=$((match_old_cp + 1))
    fi

    if [ $diff_new -eq 0 ]; then
        match_new_cp=$((match_new_cp + 1))
    fi

done

# clean up
python -c "import checkpoint; checkpoint.clear_checkpoint('${TEST_DIR}')"
set -m

# print stats
printf "\n"
echo "Matched old checkpoint ${CP_OLD}: ${match_old_cp} times"
echo "Matched new checkpoint ${CP_NEW}: ${match_new_cp} times"
