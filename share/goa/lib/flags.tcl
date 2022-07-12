#
# CPP flags
#
set include_dirs { }
foreach api $used_apis {
	set dir [file join $depot_dir $api include]

	if {$arch == "x86_64"} {
		lappend include_dirs [file join $dir spec x86_64]
		lappend include_dirs [file join $dir spec x86]
	}
	if {$arch == "arm_v8a"} {
		lappend include_dirs [file join $dir spec arm_64]
	}
	lappend include_dirs [file join $dir spec 64bit]
	lappend include_dirs $dir
}

set libgcc_path    [file normalize [eval "exec $cross_dev_prefix\gcc -print-libgcc-file-name"]]
set libgcc_include [file join [file dirname $libgcc_path] include]

lappend include_dirs [file normalize $libgcc_include]

set cppflags { }
lappend cppflags "-nostdinc"

#
# The 'cppflags' variable is extended with the include paths after 'quirks.tcl'
# is processed.
#


#
# C-compiler flags
#
set cflags { }
lappend cflags -fPIC
lappend cflags $olevel

if {$cc_march != ""} {
	lappend cflags $cc_march }

if {[info exists warn_strict] && $warn_strict} {
	lappend cflags -Wall }


#
# C++-compiler flags
#
set cxxflags $cflags

if {[info exists warn_strict] && $warn_strict} {
	lappend cxxflags -Wextra -Weffc++ -Werror -Wsuggest-override }


#
# Linker flags
#
set ld_script_dir [file join $tool_dir ld]

set     ldflags { }
lappend ldflags -gc-sections
lappend ldflags -z max-page-size=0x1000
lappend ldflags -Ttext=0x01000000
lappend ldflags --dynamic-linker=ld.lib.so
lappend ldflags --dynamic-list=[file join $ld_script_dir genode_dyn.dl]
lappend ldflags --eh-frame-hdr -rpath-link=.
lappend ldflags -T [file join $ld_script_dir genode_dyn.ld]

if {$ld_march != ""} {
	lappend ldflags $ld_march }

# apply linker-argument prefix -Wl, to each flag
set prefixed_flags { }
foreach flag $ldflags {
	lappend prefixed_flags "-Wl,$flag" }
set ldflags $prefixed_flags

#
# Linker flags for shared objects
#
# to support shared objects add <user>/api/so to the used_apis file
set ldsoflags { }
lappend ldsoflags $ld_march
lappend ldsoflags -gc-sections
lappend ldsoflags -z max-page-size=0x1000
lappend ldsoflags --entry=0x0
lappend ldsoflags --eh-frame-hdr
lappend ldsoflags -T [file join $ld_script_dir genode_rel.ld]

set prefixed_flags { }
foreach flag $ldsoflags {
	lappend prefixed_flags "-Wl,$flag" }
set ldsoflags $prefixed_flags

# search for so_support.c
set so_support "so_support"
foreach api $used_apis {
	set so_support_file [file join $depot_dir $api src lib ldso $so_support.c]
	if {[file exists $so_support_file]} {
		file mkdir $abi_dir
		exec $cross_dev_prefix\gcc -m64 -fPIC -c $so_support_file -o [file join $abi_dir $so_support.o]
		break
	}
}

lappend ldsoflags [file join $abi_dir $so_support.o]


#
# Library arguments for the linker
#
set     ldlibs { }
lappend ldlibs -nostartfiles -nodefaultlibs -static-libgcc
lappend ldlibs -L$abi_dir

# determine ABIs to link against the executable
set abis { }
foreach api $used_apis {
	set symbol_files [glob -nocomplain -directory [file join $depot_dir $api lib symbols] *]
	foreach symbol_file $symbol_files {
		lappend abis [file tail $symbol_file] } }

foreach abi $abis {
	lappend ldlibs "-l:$abi.lib.so" }
