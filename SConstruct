#!/usr/bin/env python
import os
import sys

env = SConscript("godot-cpp/SConstruct")

if env["platform"] == "linux":
    if os.environ.get("LINUX_CC") and os.environ.get("LINUX_CXX"):
        env["CC"] = os.environ["LINUX_CC"]
        env["CXX"] = os.environ["LINUX_CXX"]

# For reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "theSandbox/bin/gdexample.{}.{}.framework/gdexample.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "theSandbox/bin/gdexample{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)


