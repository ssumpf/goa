#!/usr/bin/env expect

#
# \brief  Simple script to self-test Goa
# \author Sebastian Sumpf
# \date   2023-06-09
#
# The script looks for the projects defined in 'test.list' (format:
# <test>[:timeout]) in the 'examples' folder of this project.  If the project
# contains a "test/artifact" file, the script executes the project and compares
# the output to the first line in the 'test/artifact' file.  In case the line
# matches the output it is evaluated as success.
#

proc _find_tool_dir { } {
	global goa

	set path $goa
	if {[file type $path] == "link"} {

		set link_target [file readlink $path]

		# resolve relative symlink used as symlink target
		if {[file pathtype $link_target] == "relative"} {
			set path [file join [file dirname $argv0] $link_target]
			set path [file normalize $path]
		} else {
			set path $link_target
		}
	}

	# strip binary name and 'bin/' path
	return [file dirname [file dirname $path]]
}

##
## From genode/tool/run adjusted for Goa
##

##
# Wait for a specific output of a already running spawned process
#
proc wait_for_output { wait_for_re timeout_value running_spawn_id } {
	global output
	global stats

	set timeout $timeout_value

	expect {
		-i $running_spawn_id -re $wait_for_re { }
		eof     { incr stats(failed); return "failed\t(spawned process died unexpectedly)" }
		timeout { incr stats(failed); return "failed\t(test execution timed out)" }
	}

	incr stats(success)
	return "success"
}


##
# Execute goa
#
# \param  wait_for_re    regular expression that matches the test completion
# \param  timeout_value  timeout in seconds
# \return result string
#
proc run_goa_until {{test} {timeout_value 0}} {
	global goa
	global example_dir
	global stats

	# check if test exists
	set test_dir [file join $example_dir $test]
	if {![file exists $test_dir]} {
		incr stats(skipped); return "skipped\t('$test_dir' does not exists)" }

	# check for and read "test/artifact" file
	set artifact [file join $example_dir $test test artifact]
	if {![file exists $artifact]} {
		incr stats(skipped); return "skipped\t('$artifact' does not exists)" }
	set compare [read_file_content_as_list $artifact]

	# execute and compare output
	cd $test_dir
	eval spawn $goa run
	set result [wait_for_output [lindex $compare 0] $timeout_value $spawn_id]

	#
	# leave depot and public intact
	#
	exec rm -rf abi api bin build run

	return $result
}


##################
## Main program ##
##################

set goa         [exec which goa]
set tool_dir    [file join [_find_tool_dir] "share" "goa"]
set example_dir [file join [_find_tool_dir] "examples"]

set stats(success) 0
set stats(failed)  0
set stats(skipped) 0

source [file join $tool_dir lib util.tcl]

# measure duration
set start [clock milliseconds]

set tests [read_file_content_as_list [file join $tool_dir lib test.list]]

# run tests
set results { }
foreach test $tests {

	set timeout 20

	#retrieve possible timeout after ':'
	set test_args [split $test ":"]
	if {[lindex $test_args 1] != ""} {
		set test    [lindex $test_args 0]
		set timeout [lindex $test_args 1]
	}

	puts "\n--- $test ---"
	set result [run_goa_until $test $timeout]
	lappend results "$test:\t$result"
}

set end [clock milliseconds]
set delta [expr ( $end - $start ) / 1000.0]


##
## Print results
##

puts "\n\n--- Finished after $delta sec ---"
foreach result $results {
	puts $result
}

set stats_output ""
append stats_output "\nsucceeded: $stats(success) failed: $stats(failed)" \
                    " skipped: $stats(skipped) total: [llength $tests]"
puts $stats_output
