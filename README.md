# ResourceCreator.cmake

Simple CMake resource generator.

* Generates `7zip` or `zip` c file resource. 
* Generates single c file resource.
* Resources are recompiled automatically on each change on `make` call.

#### CMake Usage:
```cmake
cmake_minimum_required(VERSION 3.12)

include("${CMAKE_SOURCE_DIR}/cmake/ResourceCreator.cmake")

# creates zipped resource from arbitrary number of files 
add_resource(resourceA
	ARCHIVE zip
	file1.txt                              # relative path 
	${CMAKE_CURRENT_SOURCE_DIR}/file2.txt  # absolute path
	${CMAKE_CURRENT_BINARY_DIR}/generated_file.txt
)

# creates zipped resource preserving structure from arbitrary number of files 
add_resource(rscB
	VAR resourceB # set c file variable name, otherwise derived from resource name
	ARCHIVE zip   # zip or 7zip
	RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" # if RELATIVE is set, then file dir structure is preserved
	                                       # relatively to this directory (all files must be inside)  
	file1.txt
	data/file2.txt
	deta/nested/file3.txt
)

# creates single file resource (raw, unpacked)
add_resource(resourceC file1.txt)

# creates executable including all created resources
add_executable(app main.c)
target_link_libraries($app resourceA rscB resourceC)
```

#### C Usage:
```c
#include <stdio.h>
#include <stdlib.h>

/* include unzip lib of your choice, eg. */
/* https://github.com/isRyven/nozip */
#include "nozip.h" 

/* all resources are created as separate c files with appropriate var names */
/* extern include them inside of you main file */
extern const unsigned char resourceA[];
extern const unsigned int  resourceA_length;

extern const unsigned char resourceB[];
extern const unsigned int  resourceB_length;

extern const unsigned char resourceC[];
extern const unsigned int  resourceC_length;

int main(int argc, const char **argv)
{
	nozip_t *zip;
	nozip_entry_t *entries;
	size_t num_entries;

	/* open resourceA */
	zip = malloc(nozip_size_mem((void*)resourceA, resourceA_length)); 
	if (!zip || !(num_entries = nozip_read_mem(zip, (void*)resourceA, resourceA_length))) {
		return 1;
	}
	entries = nozip_entries(zip);
	printf("resourceA entries:\n");
	for (size_t i = 0; i < num_entries; ++i) {
		/* >> file1.txt */
		/* >> file2.txt */
		/* >> generated_file.txt */
		printf("%s\n", (entries + i)->filename);
	}
	free(zip);

	/* open resourceB */
	zip = malloc(nozip_size_mem((void*)resourceB, resourceB_length)); 
	if (!zip || !(num_entries = nozip_read_mem(zip, (void*)resourceB, resourceB_length))) {
		return 1;
	}
	entries = nozip_entries(zip);
	printf("resourceB entries:\n");
	for (size_t i = 0; i < num_entries; ++i) {
		/* >> file1.txt */
		/* >> data/file2.txt */
		/* >> deta/nested/file3.txt */
		printf("%s\n", (entries + i)->filename);
	}
	free(zip);

	/* Print contents of resourceC */
	printf("resourceC contents:\n");
	fwrite(resourceC, 1, resourceC_length, stdout);
	putc('\n', stdout);

	return 0;
} 
```
