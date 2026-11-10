# Sanitizer support, selected with -DHELIX_SANITIZER=address|thread|undefined.
#
# Applied globally (compile + link flags) so that every target, including
# GoogleTest, is instrumented the same way. Mixing instrumented and
# uninstrumented code gives false positives with TSan.
#
# Notes:
#  * ASan and TSan cannot be combined in one build; that is why the Makefile
#    uses one build directory per sanitizer (build-asan/, build-tsan/, ...).
#  * TSan on recent Linux kernels with high ASLR entropy can abort with
#    "unexpected memory mapping". Fix: `sudo sysctl vm.mmap_rnd_bits=28`
#    (see docs/runbooks/dev-environment.md, Troubleshooting).
#  * The custom allocator (day 4+) hides heap bugs from ASan; build with
#    -DHELIX_MALLOC_PASSTHROUGH=ON (added on day 4) when using ASan.

set(_helix_san_flags "")

if(HELIX_SANITIZER STREQUAL "address")
  set(_helix_san_flags -fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls)
elseif(HELIX_SANITIZER STREQUAL "thread")
  set(_helix_san_flags -fsanitize=thread -fno-omit-frame-pointer)
elseif(HELIX_SANITIZER STREQUAL "undefined")
  set(_helix_san_flags -fsanitize=undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer)
elseif(NOT HELIX_SANITIZER STREQUAL "")
  message(FATAL_ERROR "Unknown HELIX_SANITIZER='${HELIX_SANITIZER}'. Use address, thread, undefined or empty.")
endif()

if(_helix_san_flags)
  add_compile_options(${_helix_san_flags})
  add_link_options(${_helix_san_flags})
  message(STATUS "helix: sanitizer enabled: ${HELIX_SANITIZER}")
endif()

# Exposed to the code so build_info() can report it.
if(HELIX_SANITIZER STREQUAL "")
  set(HELIX_SANITIZER_NAME "none")
else()
  set(HELIX_SANITIZER_NAME "${HELIX_SANITIZER}")
endif()
