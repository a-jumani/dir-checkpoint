#!/usr/bin/env bash

# Testing strategy
#
# Definitions
#   DIR: directory checkpointed
#   OLD_CP: old checkpoint (match-old-cp/)
#   NEW_CP: new checkpoint (match-new-cp/)
#
# Simulate process failure during:
# - creation new checkpoint
#       Starting point: OLD_CP exists
#       1. DIR is updated w/ new data
#       2. NEW_CP is failed
#       3. Empty DIR and restore from checkpoint
#
# - creation first checkpoint
#       Starting point: DIR is empty, OLD_CP, NEW_CP don't exist
#       1. DIR is updated w/ new data
#       2. NEW_CP is failed
#       3. Empty DIR and restore from checkpoint
#
# - restoration from a checkpoint
#       Starting point: OLD_CP exists
#       1. Restore DIR from a checkpoint is failed
#
# - clearance of a checkpoint
#       Starting point: OLD_CP exists
#       1. Clearance of OLD_CP is failed
#       2. Restore DIR from a checkpoint
#
# Criteria: if restoring from a checkpoint completes, DIR is always
# consistent with a successful checkpoint creation operation in the past.
#
# Coverage of scenarios.

# get printing utilities
source tests-failure/print-utils.sh

# constants
TF_FOLDER="tests-failure"
TF_CP_OLD="${TF_FOLDER}/match-old-cp"
TF_CP_NEW="${TF_FOLDER}/match-new-cp"
TF_TEST_DIR="${TF_FOLDER}/test-cp"
TF_IGNORE_CHANGES="\."                         # format: <word1>|<word2>[...]
TF_SUCCESS_COUNT_NEEDED=5
TF_SLEEP_INCREMENT=0.01
TF_REP_LIMITS=100

# variables
tf_sleep_for=0
tf_tests_passed=0

# helper: replace test dir
# arg: path to dir for replacement
replace_test_dir() {
    rm -rf $TF_TEST_DIR
    cp -r $1 $TF_TEST_DIR
}

# helper: restore checkpoint
# arg: true (or equivalent) to empty TEST_DIR before restoration
restore_checkpoint() {
    if [ $1 ]; then
        rm -rf $TF_TEST_DIR
        mkdir $TF_TEST_DIR
    fi
    python -c "import checkpoint; checkpoint.restore_checkpoint('${TF_TEST_DIR}')"
}

# helper: clear checkpoint
clear_checkpoint() {
    python -c "import checkpoint; checkpoint.clear_checkpoint('${TF_TEST_DIR}')"
}

# helper: create state w/ checkpoint
# arg: path to dir for state
create_checkpointed_state() {
    replace_test_dir $1
    python -c "import checkpoint; checkpoint.create_checkpoint('${TF_TEST_DIR}')"
}

# helper: execute cmd and kill after tf_sleep_for seconds
# arg: cmd to execute
exec_and_kill() {
    # increase sleep amount
    tf_sleep_for=$(echo "scale=2; ${tf_sleep_for} + $TF_SLEEP_INCREMENT" | bc)

    # launch task and wait
    { python -c "$1" & } 2> /dev/null
    sleep $tf_sleep_for

    # kill and ignore job termination message
    { kill $! %% && wait; } 2>/dev/null
    
    # print a character to show progress
    if [ $? -eq 0 ]; then
        printf "."
    fi
}

# helper: reset sleep interval
reset_sleep() {
    tf_sleep_for=0
}

# helper: print results 2 checkpoints
# arg1: {0, 1}, where 0 means inconsistency detected
# arg2: number of repetitions completed
# arg3: number of matches with new checkpoint
# arg4: number of matches with old checkpoint
print_two_cp_test() {
    if [ $1 -eq 0 ]; then
        print_test_failure "restored checkpoint (${TF_TEST_DIR}) is inconsistent"
    elif [ $2 -eq $TF_REP_LIMITS ]; then
        print_test_failure "successful creation of new checkpoint ($3) happened < $TF_SUCCESS_COUNT_NEEDED times"
        print_possible_remedy "Could also mean TF_SLEEP_INCREMENT is too low for your system"
    elif [ $4 -eq 0 ];  then
        print_test_failure "new checkpoint creation never failed"
        print_possible_remedy "Could also mean TF_SLEEP_INCREMENT is too high for your system"
    else
        print_test_success "restored checkpoints were always consistent"
        tf_tests_passed=$((tf_tests_passed + 1))
    fi
}

# helper: print usage
print_usage() {
    echo "usage: ./tests-failure/tests.sh <test> || set -m,"
    echo "where <test> in {0, 1, 2, 3, 4} s.t."
    echo "    0: run all tests"
    echo "    1: test for creation new checkpoint"
    echo "    2: test for creation first checkpoint"
    echo "    3: test for restoration from a checkpoint"
    echo "    4: test for clearance of a checkpoint"
}

# covers creation new checkpoint
test1() {
    print_test_st "Failure creating new checkpoint"
    
    # reset failure simulation
    reset_sleep
    
    # track progress
    local consistent=1                      # test pass status
    local reps=0                            # failures triggered

    # check consistency
    local diff_new                          # no. of differences in TEST_DIR and new cp
    local diff_old                          # no. of differences in TEST_DIR and old cp

    # counters
    local match_old_cp=0                    # no. of times in TEST_DIR was at old cp
    local match_new_cp=0                    # no. of times in TEST_DIR was at new cp

    # create old state w/ checkpoint
    create_checkpointed_state $TF_CP_OLD

    # repeat test until restore successfully picks up the new checkpoint a few times
    # or repetition limit is reached
    while [ $match_new_cp -lt $TF_SUCCESS_COUNT_NEEDED -a $reps -lt $TF_REP_LIMITS ]; do

        reps=$((reps + 1))

        # update test dir
        replace_test_dir $TF_CP_NEW

        # trigger creation of new checkpoint with failure possibility
        exec_and_kill "import checkpoint; checkpoint.create_checkpoint('${TF_TEST_DIR}')"

        # clear TEST_DIR and restore checkpoint
        restore_checkpoint 1

        # calculate number of diffs with checkpoints
        diff_old=$(diff -r $TF_TEST_DIR $TF_CP_OLD | grep -Ev $TF_IGNORE_CHANGES | wc -l)
        diff_new=$(diff -r $TF_TEST_DIR $TF_CP_NEW | grep -Ev $TF_IGNORE_CHANGES | wc -l)
        
        # test failure condition: TEST_DIR doesn't match either checkpoints
        if [ $diff_old -gt 0 -a $diff_new -gt 0 ]; then
            consistent=0
            break
        fi

        # update matches
        if [ $diff_old -eq 0 ]; then
            match_old_cp=$((match_old_cp + 1))
        else
            match_new_cp=$((match_new_cp + 1))
        fi

    done

    printf "\n"

    # clean up
    clear_checkpoint

    # print results
    print_two_cp_test $consistent $reps $match_new_cp $match_old_cp

    # print stats
    echo "Matched old checkpoint ${TF_CP_OLD}: ${match_old_cp} times"
    echo "Matched new checkpoint ${TF_CP_NEW}: ${match_new_cp} times"
}

# covers creation first checkpoint
test2() {
    print_test_st "Failure creating first checkpoint"

    # reset failure simulation
    reset_sleep

    # track progress
    local consistent=1                      # test pass status
    local reps=0                            # failures triggered

    # check consistency
    local diff_empty                        # no. of differences in TEST_DIR and empty dir
    local diff_new                          # no. of differences in TEST_DIR and new cp
    
    # counters
    local match_empty_cp=0                  # no. of times in TEST_DIR was empty
    local match_new_cp=0                    # no. of times in TEST_DIR was at new cp

    # create empty state
    rm -rf $TF_TEST_DIR
    mkdir $TF_TEST_DIR

    # repeat test until restore successfully picks up the new checkpoint a few times
    # or repetition limit is reached
    while [ $match_new_cp -lt $TF_SUCCESS_COUNT_NEEDED -a $reps -lt $TF_REP_LIMITS ]; do

        reps=$((reps + 1))
        
        # update test dir
        replace_test_dir $TF_CP_NEW

        # trigger creation of first checkpoint with failure possibility
        exec_and_kill "import checkpoint; checkpoint.create_checkpoint('${TF_TEST_DIR}')"

        # clear TEST_DIR and restore checkpoint
        restore_checkpoint 1

        # calculate number of diffs with checkpoints
        diff_empty=$(ls -a $TF_TEST_DIR | grep -Ev $TF_IGNORE_CHANGES | wc -l)
        diff_new=$(diff -r $TF_TEST_DIR $TF_CP_NEW | grep -Ev $TF_IGNORE_CHANGES | wc -l)
        
        # test failure condition: TEST_DIR doesn't match either checkpoints
        if [ $diff_empty -gt 0 -a $diff_new -gt 0 ]; then
            consistent=0
            break
        fi

        # update matches
        if [ $diff_empty -eq 0 ]; then
            match_empty_cp=$((match_empty_cp + 1))
        else
            match_new_cp=$((match_new_cp + 1))
        fi

    done

    printf "\n"

    # clean up
    clear_checkpoint

    # print results
    print_two_cp_test $consistent $reps $match_new_cp $match_empty_cp

    # print stats
    echo "Matched empty checkpoint: ${match_empty_cp} times"
    echo "Matched new checkpoint ${TF_CP_NEW}: ${match_new_cp} times"
}

# covers restoration from a checkpoint
test3() {
    print_test_st "Failure restoring a checkpoint, i.e. testing idempotence."

    # reset failure simulation
    reset_sleep

    # track progress
    local reps=0                            # failures triggered
    
    # check consistency
    local diff_old                          # no. of differences in TEST_DIR and old cp

    # counters
    local match_old_cp=0                    # no. of times in TEST_DIR was at old cp
    local no_match_old_cp=0                 # no. of times in TEST_DIR was not at old cp

    # create old state w/ checkpoint
    create_checkpointed_state $TF_CP_OLD

    # update state
    replace_test_dir $TF_CP_NEW

    # repeat test until restore successfully picks up the checkpoint a few times
    # or repetition limit is reached
    while [ $match_old_cp -lt $TF_SUCCESS_COUNT_NEEDED -a $reps -lt $TF_REP_LIMITS ]; do

        reps=$((reps + 1))
        
        # fail restoration of checkpoint
        exec_and_kill "import checkpoint; checkpoint.restore_checkpoint('${TF_TEST_DIR}')"

        # calculate number of diffs with checkpoint
        diff_old=$(diff -r $TF_TEST_DIR $TF_CP_OLD | grep -Ev $TF_IGNORE_CHANGES | wc -l)

        # update matches with old cp
        if [ $diff_old -eq 0 ]; then
            match_old_cp=$((match_old_cp + 1))
        else
            no_match_old_cp=$((no_match_old_cp + 1))
        fi

    done

    printf "\n"
    
    # clean up
    clear_checkpoint

    # print results
    if [ $reps -eq $TF_REP_LIMITS ]; then
        print_test_failure "successful restoration of old checkpoint ($match_old_cp) happened < $TF_SUCCESS_COUNT_NEEDED times"
        print_possible_remedy "Could also mean TF_SLEEP_INCREMENT is too low for your system"
    elif [ $no_match_old_cp -eq 0 ];  then
        print_test_failure "restoration never failed"
        print_possible_remedy "Could also mean TF_SLEEP_INCREMENT is too high for your system"
    else
        print_test_success "restoration yielded consistent data when it eventually succeeded"
        tf_tests_passed=$((tf_tests_passed + 1))
    fi

    # print stats
    echo "Unsuccessful restores: ${no_match_old_cp} times"
    echo "Matched old checkpoint ${TF_CP_OLD}: ${match_old_cp} times"
}

# covers clearance of a checkpoint
test4() {
    print_test_st "Failure clearing a checkpoint, i.e. testing idempotence."

    # reset failure simulation
    reset_sleep

    # track progress
    local consistent=1                      # test pass status
    local reps=0                            # failures triggered

    # check consistency
    local diff_empty                        # no. of differences in TEST_DIR and empty dir
    local diff_old                          # no. of differences in TEST_DIR and old cp

    # counters
    local match_old_cp=0                    # no. of times in TEST_DIR was at old cp
    local match_empty_cp=0                  # no. of times in TEST_DIR was empty

    # create old state w/ checkpoint
    create_checkpointed_state $TF_CP_OLD

    # repeat test until restore successfully picks up the checkpoint a few times
    while [ $match_empty_cp -lt $TF_SUCCESS_COUNT_NEEDED -a $reps -lt $TF_REP_LIMITS ]; do

        reps=$((reps + 1))

        # fail clearance of checkpoint
        exec_and_kill "import checkpoint; checkpoint.clear_checkpoint('${TF_TEST_DIR}')"

        # restore checkpoint
        restore_checkpoint

        # calculate number of diffs with checkpoints
        diff_old=$(diff -r $TF_TEST_DIR $TF_CP_OLD | grep -Ev $TF_IGNORE_CHANGES | wc -l)
        diff_empty=$(ls -a $TF_TEST_DIR | grep -Ev $TF_IGNORE_CHANGES | wc -l)

        if [ $diff_empty -gt 0 -a $diff_old -gt 0 ]; then
            consistent=0
            break
        fi

        # update matches
        if [ $diff_old -eq 0 ]; then
            match_old_cp=$((match_old_cp + 1))
        else
            match_empty_cp=$((match_empty_cp + 1))
        fi

    done

    printf "\n"
    
    # clean up
    clear_checkpoint

    # print results
    print_two_cp_test $consistent $reps $match_empty_cp $match_old_cp

    # print stats
    echo "Unsuccessful checkpoint clearance: ${match_old_cp} times"
    echo "Successful checkpoint clearance: ${match_empty_cp} times"
}

print_apply_settings

# parse argument and run tests
if [ $# -eq 0 ]; then
    print_usage
elif [ $1 -eq 1 ]; then
    test1
elif [ $1 -eq 2 ]; then
    test2
elif [ $1 -eq 3 ]; then
    test3
elif [ $1 -eq 4 ]; then
    test4
elif [ $1 -eq 0 ]; then
    test1
    test2
    test3
    test4
else
    print_usage
fi
print_completion $tf_tests_passed

print_reverse_settings
