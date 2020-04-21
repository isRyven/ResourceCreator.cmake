# MIT License
 
# Copyright (c) 2020 isRyven<ryven.mt@gmail.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# normal run, inclusion block
if (NOT RSC_CREATE)
	# cache script path
	set(RSC_SCRIPT "${CMAKE_CURRENT_LIST_FILE}")

	function(add_resource rscName)
		# parse named arguments
		set(options "")
	    set(args VAR RELATIVE ARCHIVE)
	    set(list_args "")
	    cmake_parse_arguments(PARSE_ARGV 1 arg "${options}" "${args}" "${list_args}")

	    if (NOT rscName)
	    	message(FATAL_ERROR "add_resource: resource name must be set")
	        return()
	    endif()

	   	if (NOT arg_UNPARSED_ARGUMENTS)
	        message(FATAL_ERROR "add_resource: No resource files were passed")
	        return()
	   	endif()

	    if (NOT arg_VAR)
	        set(arg_VAR "${rscName}")
	    endif()

	   	list(LENGTH arg_UNPARSED_ARGUMENTS numInputFiles)

	   	if (NOT arg_ARCHIVE AND numInputFiles GREATER 1)
	   		message(FATAL_ERROR
	   			"add_resource: In non-archival mode you can include only single file.")
	   	endif()

	   	set(SUPPORTED_ARCHIVE_TYPES zip 7zip)
		# set default
	   	if (arg_ARCHIVE AND NOT arg_ARCHIVE IN_LIST SUPPORTED_ARCHIVE_TYPES)
	        message(FATAL_ERROR 
	        	"add_resource: Invalid archive type \"${arg_ARCHIVE}\", supported are \"${SUPPORTED_ARCHIVE_TYPES}\"")
	        return()
	   	endif()

	    # set export vars
		set(RSC_ID "__rsc_${rscName}")
		set(RSC_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${RSC_ID}.c")
		set(RSC_OUTPUT_VAR "${arg_VAR}")
		set(RSC_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${RSC_ID}")
		set(RSC_INPUT "${arg_UNPARSED_ARGUMENTS}")
		set(RSC_RELATIVE "${arg_RELATIVE}")
		set(RSC_ARCHIVE "${arg_ARCHIVE}")

		add_custom_command(
			OUTPUT "${RSC_OUTPUT}"
			COMMAND 
				"${CMAKE_COMMAND}"
					-DRSC_CREATE=ON
					-DRSC_DEBUG=ON
					-DRSC_ID="${RSC_ID}"
					-DRSC_OUTPUT="${RSC_OUTPUT}"
					-DRSC_OUTPUT_VAR="${RSC_OUTPUT_VAR}"
					-DRSC_OUTPUT_DIR="${RSC_OUTPUT_DIR}"
					-DRSC_INPUT="${RSC_INPUT}"
					-DRSC_RELATIVE="${RSC_RELATIVE}"
					-DRSC_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
					-DRSC_ARCHIVE="${RSC_ARCHIVE}"
					-P "${RSC_SCRIPT}"
			DEPENDS ${arg_UNPARSED_ARGUMENTS}
			COMMENT "Create \"${rscName}\" resource file"
		)

		set("${rscName}" "${RSC_OUTPUT}" PARENT_SCOPE)
	endfunction()

	return()
endif()

function(generate_c_file inpath outpath rcname)
	file(READ "${inpath}" file_bytes HEX)
	# optional null termination
	list(LENGTH ARGN num_extra_args)
	if (${num_extra_args} GREATER 0)
		list(GET ARGN 0 append_null)
		if ("${append_null}" EQUAL 1)
			string(APPEND file_bytes "00")
		endif()
	endif()
	# append hex prefixes
    string(REGEX REPLACE "(..)(..)(..)(..)(..)" "0x\\1,0x\\2,0x\\3,0x\\4,0x\\5," hex_codes "${file_bytes}")
    string(LENGTH "${file_bytes}" n_bytes2)
    math(EXPR file_size "${n_bytes2} / 2")
    math(EXPR remainder "${file_size} % 5")
    set(cleanup_re "$")
    set(cleanup_sub )
    while(remainder)
        set(cleanup_re "(..)${cleanup_re}")
        set(cleanup_sub "0x\\${remainder},${cleanup_sub}")
        math(EXPR remainder "${remainder} - 1")
    endwhile()
    if(NOT cleanup_re STREQUAL "$")
        string(REGEX REPLACE "${cleanup_re}" "${cleanup_sub}" hex_codes "${hex_codes}")
    endif()
    string(CONFIGURE [[
        const unsigned char @rcname@[] = {
            @hex_codes@
        };
        const unsigned int @rcname@_length = @file_size@; 
    ]] code)
    file(WRITE "${outpath}" "${code}")
endfunction()

function(create_c_resource)
	if (RSC_DEBUG)
		message(STATUS "ID: ${RSC_ID}")                 # RSC_ID (resource id)
		message(STATUS "OUTPUT: ${RSC_OUTPUT}")         # RSC_OUTPUT (c file output)
		message(STATUS "OUTPUT_VAR: ${RSC_OUTPUT_VAR}") # RSC_OUTPUT_VAR (c file var name)
		message(STATUS "OUTPUT_DIR: ${RSC_OUTPUT_DIR}") # RSC_OUTPUT_DIR (temp storage for files)
		message(STATUS "INPUT: ${RSC_INPUT}")           # RSC_INPUT (list of files to include)
		message(STATUS "RELATIVE: ${RSC_RELATIVE}")     # RSC_RELATIVE (file list relative to)
		message(STATUS "SOURCE DIR: ${RSC_SOURCE_DIR}") # RSC_SOURCE_DIR (CMAKE_CURRENT_SOURCE_DIR)
		message(STATUS "ARCHIVE: ${RSC_ARCHIVE}")       # RSC_ARCHIVE (archive type, if any)
	endif()

	# in non-archival mode, just generate c file resource out of input file
	if (NOT RSC_ARCHIVE)
		get_filename_component(inputFilePath ${RSC_INPUT} ABSOLUTE BASE_DIR ${RSC_SOURCE_DIR})
		if (RSC_DEBUG)
			message(STATUS "generating c resource file \"${RSC_OUTPUT}\" from \"${inputFilePath}\"")
		endif()
		generate_c_file("${inputFilePath}" "${RSC_OUTPUT}" "${RSC_OUTPUT_VAR}")
		return()
	endif()

	# convert input into list
	string(REPLACE " " ";" RSC_INPUT ${RSC_INPUT})

	set(dstRelativeInputPaths "")
	set(srcAbsoluteInputPaths "")
	# if RSC_RELATIVE is set, then strip any relative directory prefix 
	# from the absolute paths of the input files, to retain the directory structure
	# otherwise just get the file basenames
	if (RSC_RELATIVE)
		string(LENGTH "${RSC_RELATIVE}" baseDirectoryLength)
		foreach (inputFile IN LISTS RSC_INPUT)
			# resolve any relative path
			get_filename_component(inputFilePath ${inputFile} ABSOLUTE BASE_DIR ${RSC_RELATIVE})
			# strip the relative directory and optional leading path separator
			string(SUBSTRING ${inputFilePath} ${baseDirectoryLength} -1 relativeInputFilePath)
			string(REGEX REPLACE "^[/\\]" "" relativeInputFilePath ${relativeInputFilePath})
			# store destination relative path and resolved absolute path 
			list(APPEND dstRelativeInputPaths ${relativeInputFilePath})
			list(APPEND srcAbsoluteInputPaths ${inputFilePath})
		endforeach()
	else()
		foreach (inputFile IN LISTS RSC_INPUT)
			get_filename_component(inputFilePath ${inputFile} ABSOLUTE BASE_DIR ${RSC_SOURCE_DIR})
			get_filename_component(inputFileName ${inputFile} NAME)
			list(APPEND dstRelativeInputPaths ${inputFileName})
			list(APPEND srcAbsoluteInputPaths ${inputFilePath})
		endforeach()
	endif()

	set(RSC_OUTPUT_PAK "${RSC_OUTPUT_DIR}/${RSC_ID}.${RSC_ARCHIVE}")

	# copy all the files into fresh directory 
	file(REMOVE_RECURSE ${RSC_OUTPUT_DIR})
	file(MAKE_DIRECTORY ${RSC_OUTPUT_DIR})
	# get num of input files
	list(LENGTH srcAbsoluteInputPaths numRelativeInputPaths)
	math(EXPR numRelativeInputPaths "${numRelativeInputPaths} - 1")
	foreach(i RANGE ${numRelativeInputPaths})
	  	list(GET srcAbsoluteInputPaths ${i} srcInputFile)
	  	list(GET dstRelativeInputPaths ${i} dstInputFile)
		configure_file("${srcInputFile}" "${RSC_OUTPUT_DIR}/${dstInputFile}" COPYONLY)
	  	if (RSC_DEBUG)
			message(STATUS "\"${srcInputFile}\" -> \"${RSC_OUTPUT_DIR}/${dstInputFile}\"")
		endif()
	endforeach()

	if (RSC_DEBUG)
		message(STATUS "creating resource archive \"${RSC_OUTPUT_PAK}\"")
	endif()

	execute_process(
	    COMMAND ${CMAKE_COMMAND} -E tar "cfv" ${RSC_OUTPUT_PAK} --format=${RSC_ARCHIVE} ${dstRelativeInputPaths}
	    WORKING_DIRECTORY ${RSC_OUTPUT_DIR}
	)

	if (RSC_DEBUG)
		message(STATUS "generating c resource file \"${RSC_OUTPUT}\"")
	endif()

	generate_c_file("${RSC_OUTPUT_PAK}" "${RSC_OUTPUT}" "${RSC_OUTPUT_VAR}")
endfunction()

# run create resource block 
create_c_resource()
