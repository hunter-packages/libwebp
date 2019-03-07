# Generate the config.h to compile with specific intrinsics / libs.

# Check for compiler options.
include(CheckCSourceCompiles)
check_c_source_compiles("
    int main(void) {
      (void)__builtin_bswap16(0);
      return 0;
    }
  " HAVE_BUILTIN_BSWAP16)
check_c_source_compiles("
    int main(void) {
      (void)__builtin_bswap32(0);
      return 0;
    }
  " HAVE_BUILTIN_BSWAP32)
check_c_source_compiles("
    int main(void) {
      (void)__builtin_bswap64(0);
      return 0;
    }
  " HAVE_BUILTIN_BSWAP64)

# Check for libraries.
find_package(Threads)
if(Threads_FOUND)
  if(CMAKE_USE_PTHREADS_INIT)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pthread")
  endif()
  foreach(PTHREAD_TEST HAVE_PTHREAD_PRIO_INHERIT PTHREAD_CREATE_UNDETACHED)
    check_c_source_compiles("
        #include <pthread.h>
        int main (void) {
          int attr = ${PTHREAD_TEST};
          return attr;
        }
      " ${PTHREAD_TEST})
  endforeach()
  list(APPEND WEBP_DEP_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})
endif()
set(WEBP_USE_THREAD ${Threads_FOUND})

# TODO: this seems unused, check with autotools.
set(LT_OBJDIR ".libs/")

# Only useful for vwebp, so useless for now.
find_package(OpenGL)
set(WEBP_HAVE_GL ${OPENGL_FOUND})

# Check if we need to link to the C math library. We do not look for it as it is
# not found when cross-compiling, while it is here.
check_c_source_compiles("
    #include <math.h>
    int main(int argc, char** argv) {
      return (int)pow(argc, 2.5);
    }
  " HAVE_MATH_LIBRARY)
if(NOT HAVE_MATH_LIBRARY)
  message(STATUS "Adding -lm flag.")
  list(APPEND WEBP_DEP_LIBRARIES m)
endif()

if(HUNTER_ENABLED)
  hunter_add_package(PNG)
  find_package(PNG CONFIG REQUIRED)
  list(APPEND WEBP_DEP_IMG_LIBRARIES PNG::png)
  set(WEBP_HAVE_PNG 1)
  set(PNG_FOUND 1)

  hunter_add_package(Jpeg)
  find_package(JPEG CONFIG REQUIRED)
  list(APPEND WEBP_DEP_IMG_LIBRARIES JPEG::jpeg)
  set(WEBP_HAVE_JPEG 1)
  set(JPEG_FOUND 1)

  if(MSYS)
    # TIFF is currently not supported by Hunter on MSYS:
    # - https://github.com/ingenue/hunter/blob/8e37b969b18ff75857d2b75c8acdf1e9caca2549/appveyor.yml#L31-L34
    set(WEBP_HAVE_TIFF 0)
    set(TIFF_FOUND 0)
  else()
    hunter_add_package(TIFF)
    find_package(TIFF CONFIG REQUIRED)
    list(APPEND WEBP_DEP_IMG_LIBRARIES TIFF::libtiff)
    set(WEBP_HAVE_TIFF 1)
    set(TIFF_FOUND 1)
  endif()

  if(MINGW OR MSYS)
    # giflib is currently not supported by Hunter on MinGW and MSYS:
    # - https://github.com/ingenue/hunter/blob/ab5a2b7507427b2e1110717c35c29a78815394c6/appveyor.yml#L27-L37
    set(WEBP_HAVE_GIF 0)
    set(GIF_FOUND 0)
  else()
    hunter_add_package(giflib)
    find_package(giflib CONFIG REQUIRED)
    list(APPEND WEBP_DEP_GIF_LIBRARIES giflib::giflib)
    set(WEBP_HAVE_GIF 1)
    set(GIF_FOUND 1)
  endif()
else()

# Find the standard image libraries.
set(WEBP_DEP_IMG_LIBRARIES)
set(WEBP_DEP_IMG_INCLUDE_DIRS)
foreach(I_LIB PNG JPEG TIFF)
  find_package(${I_LIB})
  set(WEBP_HAVE_${I_LIB} ${${I_LIB}_FOUND})
  if(${I_LIB}_FOUND)
    list(APPEND WEBP_DEP_IMG_LIBRARIES ${${I_LIB}_LIBRARIES})
    list(APPEND WEBP_DEP_IMG_INCLUDE_DIRS ${${I_LIB}_INCLUDE_DIR}
                ${${I_LIB}_INCLUDE_DIRS})
  endif()
endforeach()
if(WEBP_DEP_IMG_INCLUDE_DIRS)
  list(REMOVE_DUPLICATES WEBP_DEP_IMG_INCLUDE_DIRS)
endif()

# GIF detection, gifdec isn't part of the imageio lib.
include(CMakePushCheckState)
set(WEBP_DEP_GIF_LIBRARIES)
set(WEBP_DEP_GIF_INCLUDE_DIRS)
find_package(GIF)
set(WEBP_HAVE_GIF ${GIF_FOUND})
if(GIF_FOUND)
  # GIF find_package only locates the header and library, it doesn't fail
  # compile tests when detecting the version, but falls back to 3 (as of at
  # least cmake 3.7.2). Make sure the library links to avoid incorrect detection
  # when cross compiling.
  cmake_push_check_state()
  set(CMAKE_REQUIRED_LIBRARIES ${GIF_LIBRARIES})
  set(CMAKE_REQUIRED_INCLUDES ${GIF_INCLUDE_DIR})
  check_c_source_compiles("
      #include <gif_lib.h>
      int main(void) {
        (void)DGifOpenFileHandle;
        return 0;
      }
      " GIF_COMPILES)
  cmake_pop_check_state()
  if(GIF_COMPILES)
    list(APPEND WEBP_DEP_GIF_LIBRARIES ${GIF_LIBRARIES})
    list(APPEND WEBP_DEP_GIF_INCLUDE_DIRS ${GIF_INCLUDE_DIR})
  else()
    unset(GIF_FOUND)
  endif()
endif()

endif()

# Check for specific headers.
include(CheckIncludeFiles)
check_include_files("stdlib.h;stdarg.h;string.h;float.h" STDC_HEADERS)
check_include_files(dlfcn.h HAVE_DLFCN_H)
check_include_files(GLUT/glut.h HAVE_GLUT_GLUT_H)
check_include_files(GL/glut.h HAVE_GL_GLUT_H)
check_include_files(inttypes.h HAVE_INTTYPES_H)
check_include_files(memory.h HAVE_MEMORY_H)
check_include_files(OpenGL/glut.h HAVE_OPENGL_GLUT_H)
check_include_files(shlwapi.h HAVE_SHLWAPI_H)
check_include_files(stdint.h HAVE_STDINT_H)
check_include_files(stdlib.h HAVE_STDLIB_H)
check_include_files(strings.h HAVE_STRINGS_H)
check_include_files(string.h HAVE_STRING_H)
check_include_files(sys/stat.h HAVE_SYS_STAT_H)
check_include_files(sys/types.h HAVE_SYS_TYPES_H)
check_include_files(unistd.h HAVE_UNISTD_H)
check_include_files(wincodec.h HAVE_WINCODEC_H)
check_include_files(windows.h HAVE_WINDOWS_H)

# Windows specifics
if(HAVE_WINCODEC_H)
  list(APPEND WEBP_DEP_LIBRARIES
              shlwapi
              ole32
              windowscodecs)
endif()

# Check for SIMD extensions.
include(${CMAKE_CURRENT_LIST_DIR}/cpu.cmake)

# Define extra info.
set(PACKAGE ${PROJECT_NAME})
set(PACKAGE_NAME ${PROJECT_NAME})

# Read from configure.ac.
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/configure.ac CONFIGURE_AC)
string(REGEX MATCHALL
             "\\[([0-9a-z\\.:/]*)\\]"
             CONFIGURE_AC_PACKAGE_INFO
             ${CONFIGURE_AC})
function(strip_bracket VAR)
  string(LENGTH ${${VAR}} TMP_LEN)
  math(EXPR TMP_LEN ${TMP_LEN}-2)
  string(SUBSTRING ${${VAR}}
                   1
                   ${TMP_LEN}
                   TMP_SUB)
  set(${VAR} ${TMP_SUB} PARENT_SCOPE)
endfunction()

list(GET CONFIGURE_AC_PACKAGE_INFO 1 PACKAGE_VERSION)
strip_bracket(PACKAGE_VERSION)
list(GET CONFIGURE_AC_PACKAGE_INFO 2 PACKAGE_BUGREPORT)
strip_bracket(PACKAGE_BUGREPORT)
list(GET CONFIGURE_AC_PACKAGE_INFO 3 PACKAGE_URL)
strip_bracket(PACKAGE_URL)

# Build more info.
set(PACKAGE_STRING "${PACKAGE_NAME} ${PACKAGE_VERSION}")
set(PACKAGE_TARNAME ${PACKAGE_NAME})
set(VERSION ${PACKAGE_VERSION})
