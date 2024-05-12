#VARIANT ?= android
VARIANT ?= openjdk
BUILD := build/$(VARIANT)

COMPILER := $(shell CXX="${CXX}" misc/compiler.sh)
COMPILER_MAJOR_VERSION := $(shell CXX="${CXX}" misc/compiler-major-version.sh)

ifeq ($(COMPILER), clang)
	CXXFLAGS_WARNINGS := -Weverything -Wno-c++98-compat -Wno-c++98-compat-pedantic -Wno-exit-time-destructors
	ifeq ($(shell test $(COMPILER_MAJOR_VERSION) -gt 4; echo $$?),0)
		CXXFLAGS_WARNINGS += -Wno-unused-template
	endif
else ifeq ($(COMPILER), gcc)
	CXXFLAGS_WARNINGS := -Wall -Wextra -pedantic -Wno-unused-but-set-variable
endif

CXXFLAGS := $(CXXFLAGS) --std=c++14 -fPIC -Iinclude $(CXXFLAGS_WARNINGS) -Werror
CXXFLAGS_system := 
CXXFLAGS_android := -g -Itest/android -Wno-padded
CXXFLAGS_openjdk := -g -Itest/openjdk -Wno-padded -Wno-reserved-id-macro

CUFLAGS := -Iinclude -shared -Xcompiler -fPIC
CUFLAGS_system := 
CUFLAGS_openjdk := -Itest/openjdk 

UNAME := $(shell uname -s)
ifeq ($(UNAME), Darwin)
dylib := jnilib
LDFLAGS_shared := -dynamiclib
else ifeq ($(UNAME), Linux)
dylib := so
LDFLAGS_shared := -shared
else
$(error Cannot determine host platform)
endif

TARGETS += low_level
low_level_SOURCES := test/low_level.cpp

TARGETS += high_level
high_level_SOURCES := test/high_level.cpp

TARGETS += libhello.$(dylib)
libhello.$(dylib)_SOURCES = examples/hello.cpp
CXXFLAGS__examples/hello.cpp = -Wno-shadow
libhello.$(dylib)_LDFLAGS = $(LDFLAGS_shared)

TARGETS += libpeer.$(dylib)
libpeer.$(dylib)_SOURCES = examples/native_peer.cpp
CXXFLAGS__examples/native_peer.cpp = -Wno-shadow
libpeer.$(dylib)_LDFLAGS = $(LDFLAGS_shared)

TARGETS += libcudapeer.$(dylib)
libcudapeer.$(dylib)_SOURCES = examples/cuda_peer.cu
CXXFLAGS__examples/cuda_peer.cu = -Wno-shadow
libcudapeer.$(dylib)_LDFLAGS = $(LDFLAGS_shared)

.PHONY: all
all: $(TARGETS)

.PHONY: test
test: low_level high_level
	$(BUILD)/low_level
	$(BUILD)/high_level

.PHONY: examples
examples: libhello.$(dylib) examples/Hello.class libpeer.$(dylib) examples/NativePeer.class libcudapeer.$(dylib) examples/CudaPeer.class 
	java -Djava.library.path=$(BUILD) -Xcheck:jni -cp examples Hello $(shell whoami)
	java -Djava.library.path=$(BUILD) -Xcheck:jni -cp examples NativePeer
	java -Djava.library.path=$(BUILD) -Xcheck:jni -cp examples CudaPeer

# --------------------------------------------------------------------------------------------------

define TARGET_template
-include $(patsubst %,$(BUILD)/%.d,$$($(1)_SOURCES))
$(BUILD)/$(1): LDFLAGS = $(LDFLAGS) $$($(1)_LDFLAGS)
$(BUILD)/$(1): $(patsubst %,$(BUILD)/%.o,$$($(1)_SOURCES))
$(1): $(BUILD)/$(1)
endef

$(foreach target,$(TARGETS),$(eval $(call TARGET_template,$(target))))

# Link binaries
$(patsubst %,$(BUILD)/%,$(TARGETS)):
	nvcc $(LDFLAGS) -o $@ $^
	#$(CXX) $(CXXFLAGS) $(CXXFLAGS_$(VARIANT)) $(LDFLAGS) -o $@ $^

# Compile C++ files
$(BUILD)/%.cpp.o: %.cpp $(BUILD)/%.d
	@mkdir -p $(dir $@)
	$(CXX) -x c++ -MMD -MF $(BUILD)/$*.cpp.d $(CXXFLAGS) $(CXXFLAGS_$(VARIANT)) $(CXXFLAGS__$*.cpp) -c -o $@ $<
	
# Compile CUDA/C++ files
$(BUILD)/%.cu.o: %.cu $(BUILD)/%.d
	@mkdir -p $(dir $@)
	nvcc -MMD -MF $(BUILD)/$*.cu.d $(CUFLAGS) $(CUFLAGS_$(VARIANT)) $(CUFLAGS__$*.cu) -c -o $@ $<
	cp $(BUILD)/$*.cu.d $(BUILD)/$*.cpp.d
	cp $(BUILD)/$*.cu.o $(BUILD)/$*.cpp.o

# Compile Java files
%.class: %.java
	javac $<

clean:
	-rm -rf build
	-rm -rf examples/*.class

# Dependency tracking
.PRECIOUS = $(BUILD)/%.d
$(BUILD)/%.d: ;
-include $(DEPS)
