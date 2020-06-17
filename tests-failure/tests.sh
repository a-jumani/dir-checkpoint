#!/usr/bin/env bash

FOLDER="tests-failure"
CP_OLD="${FOLDER}/match-old-cp"
CP_NEW="${FOLDER}/match-new-cp"
TEST_DIR="${FOLDER}/test-cp"
IGNORE_CHANGES="\."             # format: <word1>|<word2>[...]
SUCCESS_COUNT_NEEDED=5

# replace test dir
replace_test_dir() {
    rm -rf $TEST_DIR
    cp -r $1 $TEST_DIR
}

# printing constants and functions for tests
RED='\033[0;31m'
NC='\033[0m'                    # no color

print_test_st() {
    echo "===================================================================="
    echo "Test $1: $2"
}


# =============== TEST 1 ===============
print_test_st "1" "Failure creating new checkpoint"
set +m

# create old state w/ checkpoint
replace_test_dir $CP_OLD
python -c "import checkpoint; checkpoint.create_checkpoint('${TEST_DIR}')"

# counters
sleep_for=0
match_old_cp=0
match_new_cp=0

# repeat test until restore successfully picks up the new checkpoint a few times
while [ $match_new_cp -lt $SUCCESS_COUNT_NEEDED ]; do

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
    diff_old=$(diff -r $TEST_DIR $CP_OLD | grep -Ev $IGNORE_CHANGES | wc -l)
    diff_new=$(diff -r $TEST_DIR $CP_NEW | grep -Ev $IGNORE_CHANGES | wc -l)
    
    if [ $diff_old -gt 0 -a $diff_new -gt 0 ]; then
        echo "${RED}Test failed:${NC} restored checkpoint (${TEST_DIR}) is inconsistent."
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


# =============== TEST 2 ===============
print_test_st "2" "Failure creating first checkpoint"
set +m

# create empty state
rm -rf $TEST_DIR
mkdir $TEST_DIR

# counters
sleep_for=0
match_empty_cp=0
match_new_cp=0

# repeat test until restore successfully picks up the new checkpoint a few times
while [ $match_new_cp -lt $SUCCESS_COUNT_NEEDED ]; do

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
    diff_empty=$(ls -a $TEST_DIR | grep -Ev $IGNORE_CHANGES | wc -l)
    diff_new=$(diff -r $TEST_DIR $CP_NEW | grep -Ev $IGNORE_CHANGES | wc -l)
    
    if [ $diff_empty -gt 0 -a $diff_new -gt 0 ]; then
        echo -e "${RED}Test failed:${NC} restored checkpoint (${TEST_DIR}) is inconsistent."
        echo "Differences from empty checkpoint: ${diff_empty}"
        echo "Differences from new checkpoint (${CP_NEW}): ${diff_new}"
        break
    fi

    if [ $diff_empty -eq 0 ]; then
        match_empty_cp=$((match_empty_cp + 1))
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
echo "Matched empty checkpoint: ${match_empty_cp} times"
echo "Matched new checkpoint ${CP_NEW}: ${match_new_cp} times"


# =============== TEST 3 ===============
print_test_st "3" "Failure restoring a checkpoint, i.e. testing idempotence."
set +m

# create old checkpoint and new state
replace_test_dir $CP_OLD
python -c "import checkpoint; checkpoint.create_checkpoint('${TEST_DIR}')"
replace_test_dir $CP_NEW

# counters
sleep_for=0
no_match_old_cp=0
match_old_cp=0

# repeat test until restore successfully picks up the checkpoint a few times
while [ $match_old_cp -lt $SUCCESS_COUNT_NEEDED ]; do

    # increase sleep amount by 0.001s
    sleep_for=$(echo "scale=2; ${sleep_for} + 0.001" | bc)

    # fail restoration of checkpoint after sleep_for time
    { python -c "import checkpoint; checkpoint.restore_checkpoint('${TEST_DIR}')" & } 2> /dev/null
    sleep $sleep_for
    { kill $! %% && wait; } 2>/dev/null
    if [ $? -eq 0 ]; then
        printf "."
    fi

    # calculate number of diffs with checkpoints
    diff_old=$(diff -r $TEST_DIR $CP_OLD | grep -Ev $IGNORE_CHANGES | wc -l)

    # update counts
    if [ $diff_old -eq 0 ]; then
        match_old_cp=$((match_old_cp + 1))
    else
        no_match_old_cp=$((no_match_old_cp + 1))
    fi

done

# clean up
python -c "import checkpoint; checkpoint.clear_checkpoint('${TEST_DIR}')"
set -m

# print stats
printf "\n"
echo "Unsuccessful restores: ${no_match_old_cp} times"
echo "Matched old checkpoint ${CP_OLD}: ${match_old_cp} times"


# =============== TEST 4 ===============
print_test_st "4" "Failure clearing a checkpoint, i.e. testing idempotence."
set +m

# create old state w/ checkpoint
replace_test_dir $CP_OLD
python -c "import checkpoint; checkpoint.create_checkpoint('${TEST_DIR}')"

# counters
sleep_for=0
match_old_cp=0
match_empty=0

# repeat test until restore successfully picks up the checkpoint a few times
while [ $match_empty -lt $SUCCESS_COUNT_NEEDED ]; do

    # increase sleep amount by 0.001s
    sleep_for=$(echo "scale=2; ${sleep_for} + 0.001" | bc)

    # fail clearance of checkpoint after sleep_for time
    { python -c "import checkpoint; checkpoint.clear_checkpoint('${TEST_DIR}')" & } 2> /dev/null
    sleep $sleep_for
    { kill $! %% && wait; } 2>/dev/null
    if [ $? -eq 0 ]; then
        printf "."
    fi

    # restore checkpoint
    python -c "import checkpoint; checkpoint.restore_checkpoint('${TEST_DIR}')"

    # calculate number of diffs with checkpoints
    diff_old=$(diff -r $TEST_DIR $CP_OLD | grep -Ev $IGNORE_CHANGES | wc -l)
    diff_empty=$(ls -a $TEST_DIR | grep -Ev $IGNORE_CHANGES | wc -l)

    if [ $diff_empty -gt 0 -a $diff_old -gt 0 ]; then
        echo -e "${RED}Test failed:${NC} restored checkpoint (${TEST_DIR}) is inconsistent."
        echo "Differences from empty checkpoint: ${diff_empty}"
        echo "Differences from old checkpoint (${CP_NEW}): ${diff_old}"
        break
    fi

    # update counts
    if [ $diff_old -eq 0 ]; then
        match_old_cp=$((match_old_cp + 1))
    else
        match_empty=$((match_empty + 1))
    fi

done

# clean up
python -c "import checkpoint; checkpoint.clear_checkpoint('${TEST_DIR}')"
set -m

# print stats
printf "\n"
echo "Unsuccessful checkpoint clearance: ${match_old_cp} times"
echo "Successful checkpoint clearance: ${match_empty} times"
