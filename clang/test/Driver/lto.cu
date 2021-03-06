// REQUIRES: clang-driver
// REQUIRES: x86-registered-target
// REQUIRES: nvptx-registered-target

// -flto causes a switch to llvm-bc object files.
// RUN: %clangxx -nocudainc -nocudalib -ccc-print-phases -c %s -flto 2> %t
// RUN: FileCheck -check-prefix=CHECK-COMPILE-ACTIONS < %t %s
//
// CHECK-COMPILE-ACTIONS: 2: compiler, {1}, ir, (host-cuda)
// CHECK-COMPILE-ACTIONS-NOT: lto-bc
// CHECK-COMPILE-ACTIONS: 12: backend, {11}, lto-bc, (host-cuda)

// RUN: %clangxx -nocudainc -nocudalib -ccc-print-phases %s -flto 2> %t
// RUN: FileCheck -check-prefix=CHECK-COMPILELINK-ACTIONS < %t %s
//
// CHECK-COMPILELINK-ACTIONS: 0: input, "{{.*}}lto.cu", cuda, (host-cuda)
// CHECK-COMPILELINK-ACTIONS: 1: preprocessor, {0}, cuda-cpp-output
// CHECK-COMPILELINK-ACTIONS: 2: compiler, {1}, ir, (host-cuda)
// CHECK-COMPILELINK-ACTIONS: 3: input, "{{.*}}lto.cu", cuda, (device-cuda, sm_20)
// CHECK-COMPILELINK-ACTIONS: 4: preprocessor, {3}, cuda-cpp-output, (device-cuda, sm_20)
// CHECK-COMPILELINK-ACTIONS: 5: compiler, {4}, ir, (device-cuda, sm_20)
// CHECK-COMPILELINK-ACTIONS: 6: backend, {5}, assembler, (device-cuda, sm_20)
// CHECK-COMPILELINK-ACTIONS: 7: assembler, {6}, object, (device-cuda, sm_20)
// CHECK-COMPILELINK-ACTIONS: 8: offload, "device-cuda (nvptx{{.*}}-nvidia-cuda:sm_20)" {7}, object
// CHECK-COMPILELINK-ACTIONS: 9: offload, "device-cuda (nvptx{{.*}}-nvidia-cuda:sm_20)" {6}, assembler
// CHECK-COMPILELINK-ACTIONS: 10: linker, {8, 9}, cuda-fatbin, (device-cuda)
// CHECK-COMPILELINK-ACTIONS: 11: offload, "host-cuda {{.*}}" {2}, "device-cuda{{.*}}" {10}, ir
// CHECK-COMPILELINK-ACTIONS: 12: backend, {11}, lto-bc, (host-cuda)
// CHECK-COMPILELINK-ACTIONS: 13: linker, {12}, image, (host-cuda)

// llvm-bc and llvm-ll outputs need to match regular suffixes
// (unfortunately).
// RUN: %clangxx %s -nocudainc -nocudalib -flto -save-temps -### 2> %t
// RUN: FileCheck -check-prefix=CHECK-COMPILELINK-SUFFIXES < %t %s
//
// CHECK-COMPILELINK-SUFFIXES: "-o" "[[CPP:.*lto-host.*\.cui]]" "-x" "cuda" "{{.*}}lto.cu"
// CHECK-COMPILELINK-SUFFIXES: "-o" "[[BC:.*lto-host.*\.bc]]" {{.*}}[[CPP]]"
// CHECK-COMPILELINK-SUFFIXES: "-o" "[[OBJ:.*lto-host.*\.o]]" {{.*}}[[BC]]"
// CHECK-COMPILELINK-SUFFIXES: "{{.*}}a.{{(out|exe)}}" {{.*}}[[OBJ]]"

// RUN: %clangxx %s -nocudainc -nocudalib -flto -S -### 2> %t
// RUN: FileCheck -check-prefix=CHECK-COMPILE-SUFFIXES < %t %s
//
// CHECK-COMPILE-SUFFIXES: "-o" "{{.*}}lto.s" "-x" "cuda" "{{.*}}lto.cu"

// RUN: not %clangxx -nocudainc -nocudalib %s -emit-llvm 2>&1 \
// RUN:    | FileCheck --check-prefix=LLVM-LINK %s
// LLVM-LINK: -emit-llvm cannot be used when linking

// -flto should cause link using gold plugin
// RUN: %clangxx -nocudainc -nocudalib \
// RUN:          -target x86_64-unknown-linux -### %s -flto 2> %t
// RUN: FileCheck -check-prefix=CHECK-LINK-LTO-ACTION < %t %s
//
// CHECK-LINK-LTO-ACTION: "-plugin" "{{.*}}{{[/\\]}}LLVMgold.{{dll|dylib|so}}"

// -flto=full should cause link using gold plugin
// RUN: %clangxx -nocudainc -nocudalib \
// RUN:          -target x86_64-unknown-linux -### %s -flto=full 2> %t
// RUN: FileCheck -check-prefix=CHECK-LINK-FULL-ACTION < %t %s
//
// CHECK-LINK-FULL-ACTION: "-plugin" "{{.*}}{{[/\\]}}LLVMgold.{{dll|dylib|so}}"

// Check that subsequent -fno-lto takes precedence
// RUN: %clangxx -nocudainc -nocudalib \
// RUN:          -target x86_64-unknown-linux -### %s -flto=full -fno-lto 2> %t
// RUN: FileCheck -check-prefix=CHECK-LINK-NOLTO-ACTION < %t %s
//
// CHECK-LINK-NOLTO-ACTION-NOT: "-plugin" "{{.*}}{{[/\\]}}LLVMgold.{{dll|dylib|so}}"

// -flto passes along an explicit debugger tuning argument.
// RUN: %clangxx -nocudainc -nocudalib \
// RUN:          -target x86_64-unknown-linux -### %s -flto -glldb 2> %t
// RUN: FileCheck -check-prefix=CHECK-TUNING-LLDB < %t %s
// RUN: %clangxx -nocudainc -nocudalib \
// RUN:          -target x86_64-unknown-linux -### %s -flto -g 2> %t
// RUN: FileCheck -check-prefix=CHECK-NO-TUNING < %t %s
//
// CHECK-TUNING-LLDB:   "-plugin-opt=-debugger-tune=lldb"
// CHECK-NO-TUNING-NOT: "-plugin-opt=-debugger-tune
