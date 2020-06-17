# variables
pu_test_num=1

# section divider (i.e. =====[...])
# arg: size of divider
print_section_divider() {
    pu_num_marks=$(printf "%${1}s")
    printf "${PU_GREEN}${pu_num_marks// /=}"
}

# start of test
# arg: test description
print_test_st() {
    print_section_divider 60
    printf "\n"
    echo -e "Test $pu_test_num: $1${PU_NC}"
    pu_test_num=$((pu_test_num + 1))
}

# test success
# arg: message
print_test_success() {
    echo -e "${PU_GREEN}Test passed:${PU_NC} $1."
}

# test failure
# arg: message
print_test_failure() {
    echo -e "${PU_RED}Test failed:${PU_NC} $1."
}

# possible remedy
# arg: message
print_possible_remedy() {
    echo -e "${PU_BLUE}- $1.${PU_NC}"
}

# summary of results
# arg: tests passed
print_completion() {
    print_section_divider 22
    printf " Test passed: $1 "
    print_section_divider 22
    printf "${NC}\n"
}

# apply settings
print_apply_settings() {
    set +m                                  # turn off job creation status
    
    # color constants
    PU_GREEN='\033[0;32m'
    PU_RED='\033[0;31m'
    PU_BLUE='\033[0;34m'
    PU_NC='\033[0m'                                # no color
}

# reverse settings
print_reverse_settings() {
    set -m
    unset pu_test_num
    unset pu_num_marks
    unset PU_GREEN
    unset PU_RED
    unset PU_NC
}
