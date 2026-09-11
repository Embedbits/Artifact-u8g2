#------------------------------------------------------------------------------#
# Returns artifact version.
#
# The name of function must consist of folder name (u8g2) and postfix
# (_GetArtifactVersion). Otherwise the buildprocess will fail.
#
# Unlike a compiler/tool artifact (gcc-arm-none-eabi, probe-rs, ...), u8g2
# ships no executable to query "--version" from - it is plain C source
# compiled straight into the project. The version is therefore not
# re-discovered here; it is only returned from the cache variable that
# u8g2_ArtifactInit() populated by reading the VERSION marker file packaged
# alongside the source tree (see U8g2Importer.sh). This means
# u8g2_ArtifactInit() MUST be called before u8g2_GetArtifactVersion().
#
# ARTIFACT_VERSION [out]: Version of artifact in format X.Y.Z
#------------------------------------------------------------------------------#
function(u8g2_GetArtifactVersion RET_VERSION)

    if(NOT DEFINED U8G2_ARTIFACT_VERSION)
        message(FATAL_ERROR "u8g2_GetArtifactVersion called before u8g2_ArtifactInit() - U8G2_ARTIFACT_VERSION is not set.")
    endif()

    set(${RET_VERSION} "${U8G2_ARTIFACT_VERSION}" PARENT_SCOPE)

endfunction()


#------------------------------------------------------------------------------#
# Initialize artifact for build.
#
# The name of function must consist of folder name (u8g2) and postfix
# (_ArtifactInit). Otherwise the buildprocess will fail.
#
# u8g2 ships its own CMakeLists.txt (a proper `u8g2` library target with
# PUBLIC include dirs for csrc/ and cppsrc/ already set up) right inside the
# packaged source tree - so this does NOT hand-roll file(GLOB ...) +
# target_include_directories() against the consuming project. It simply
# add_subdirectory()s u8g2's own CMakeLists.txt, which defines the `u8g2`
# target once and for all. Also exposes:
#   - U8G2_SOURCE_DIR       (CACHE PATH)     - root of the u8g2 source tree
#   - U8G2_ARTIFACT_VERSION (CACHE STRING)   - version read from VERSION
#
# Consume it in a project's own CMakeLists.txt with, for example:
#
#   include(<path_to_artifacts>/u8g2/ArtifactConfig.cmake)
#   u8g2_ArtifactInit(${ARTIFACT_BIN_PATH})
#   target_link_libraries(${PROJECT_NAME} PRIVATE u8g2)
#
# ARTIFACT_BIN_PATH_ARG [in]: Path to the binary (here: source) part of artifact
#------------------------------------------------------------------------------#
function(u8g2_ArtifactInit ARTIFACT_BIN_PATH_ARG)

    file(GLOB_RECURSE ALL_VERSION_FILES "${ARTIFACT_BIN_PATH_ARG}/*u8g2/VERSION")

    foreach(FILE_PATH IN LISTS ALL_VERSION_FILES)
        if(FILE_PATH MATCHES "u8g2/VERSION$")
            get_filename_component(RESOLVED_SOURCE_DIR ${FILE_PATH} DIRECTORY)
            set(RESOLVED_VERSION_FILE "${FILE_PATH}")
            break()
        endif()
    endforeach()

    if(NOT RESOLVED_SOURCE_DIR)

        message(FATAL_ERROR "u8g2 source tree (u8g2/VERSION marker) not found under: ${ARTIFACT_BIN_PATH_ARG}")

    endif()

    message(STATUS "u8g2 source found in: ${RESOLVED_SOURCE_DIR}")

    file(READ "${RESOLVED_VERSION_FILE}" READ_VERSION)
    string(STRIP "${READ_VERSION}" READ_VERSION)

    if(NOT READ_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")

        message(FATAL_ERROR "VERSION marker at ${RESOLVED_VERSION_FILE} does not contain a valid X.Y.Z version: '${READ_VERSION}'")

    endif()

    set(U8G2_SOURCE_DIR "${RESOLVED_SOURCE_DIR}" CACHE PATH "Root of the resolved u8g2 source tree" FORCE)
    set(U8G2_ARTIFACT_VERSION "${READ_VERSION}" CACHE STRING "Resolved u8g2 artifact version" FORCE)

    message(STATUS "u8g2 version: ${U8G2_ARTIFACT_VERSION}")

    # u8g2's own CMakeLists.txt declares cmake_minimum_required(VERSION 3.13).
    # add_subdirectory() would fail on that line with a fairly generic CMake
    # error if the consuming project's CMake is older - check explicitly
    # first so the failure clearly points at u8g2, not at u8g2's internals.
    set(U8G2_REQUIRED_CMAKE_VERSION "3.13")

    if(CMAKE_VERSION VERSION_LESS U8G2_REQUIRED_CMAKE_VERSION)

        message(FATAL_ERROR
            "u8g2_ArtifactInit: u8g2's CMakeLists.txt requires CMake >= ${U8G2_REQUIRED_CMAKE_VERSION}, "
            "but this project is running CMake ${CMAKE_VERSION}. Upgrade CMake (or the "
            "cmake_minimum_required() at the top of the consuming project's own "
            "CMakeLists.txt, if that is what's actually pinning the version) before calling u8g2_ArtifactInit().")

    endif()

    # Guard against add_subdirectory() being called twice on the same source
    # dir (CMake errors on that) in case u8g2_ArtifactInit() is invoked more
    # than once during the same configure run.
    if(NOT TARGET u8g2)

        # EXCLUDE_FROM_ALL keeps u8g2's own install() rules from running as
        # part of the consuming project's default install - the "u8g2"
        # target itself still builds fine, since target_link_libraries()
        # against it creates an ordinary build dependency regardless of
        # EXCLUDE_FROM_ALL.
        add_subdirectory("${U8G2_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/_artifacts/u8g2" EXCLUDE_FROM_ALL)

        message(STATUS "u8g2 library target configured from: ${U8G2_SOURCE_DIR}")

    else()

        message(STATUS "u8g2 target already configured - skipping add_subdirectory().")

    endif()

endfunction()
