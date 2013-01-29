platform = linux
mode = fast
bootimage = false
run-proguard = true
arch = x86_64
runtime-classpath = true

cc = gcc
cxx = g++
javac = "$(JAVA_HOME)/bin/javac"
java = "$(JAVA_HOME)/bin/java"
jar = "$(JAVA_HOME)/bin/jar"

cflags = -fno-rtti -fno-exceptions -DMAIN_CLASS=\"$(main-class)\"

lflags = -lz -ldl -lpthread -lm

objects = \
	$(build)/main.o

ifneq ($(mode),fast)
	options := -$(mode)
endif

ifeq ($(bootimage),true)
	options := $(options)-bootimage
	cflags += -DBOOT_IMAGE
	objects += \
		$(build)/bootimage-bin.o \
		$(build)/codeimage-bin.o
else
	options := $(options)
	ifeq ($(runtime-classpath),true)
		cflags += -DRUNTIME_CLASSPATH
	else
		objects += \
			$(build)/boot-jar.o
	endif
endif

ifneq ($(openjdk),)
	ifneq ($(openjdk-src),)
	  options := $(options)-openjdk-src
	else
		options := $(options)-openjdk
	endif

	proguard-flags += -include $(avian)/openjdk.pro
else
	proguard-flags += -overloadaggressively	
endif

ifeq ($(bootimage),true)
	avian-targets = \
		build/$(platform)-$(arch)$(options)/bootimage-generator \
		build/$(platform)-$(arch)$(options)/binaryToObject/binaryToObject \
		build/$(platform)-$(arch)$(options)/classpath.jar \
		build/$(platform)-$(arch)$(options)/libavian.a
endif

pwd = $(shell pwd)
build = $(pwd)/build
src = $(pwd)/src
stage1 = $(build)/stage1
stage2 = $(build)/stage2
resources = $(build)/resources
avian = $(pwd)/../avian
avian-build = $(avian)/build/$(platform)-$(arch)$(options)
converter = $(avian-build)/binaryToObject/binaryToObject
bootimage-generator = $(avian-build)/bootimage-generator
proguard = $(pwd)/../proguard4.8/lib/proguard.jar
scala = $(pwd)/../scala

resources-object = $(build)/resources-jar.o

avian-objects-dep = $(build)/avian-objects.d

main-class = scala.tools.nsc.MainGenericRunner

bootimage-object = $(build)/bootimage-bin.o
codeimage-object = $(build)/codeimage-bin.o

boot-jar = $(build)/boot.jar
boot-object = $(build)/boot-jar.o

jars = \
	$(avian)/build/$(platform)-$(arch)$(options)/classpath.jar \
	$(scala)/lib/akka-actors.jar \
	$(scala)/lib/jline.jar \
	$(scala)/lib/scala-actors.jar \
	$(scala)/lib/scala-actors-migration.jar \
	$(scala)/lib/scala-compiler.jar \
	$(scala)/lib/scala-library.jar \
	$(scala)/lib/scala-partest.jar \
	$(scala)/lib/scalap.jar \
	$(scala)/lib/scala-reflect.jar \
	$(scala)/lib/scala-swing.jar \
	$(scala)/lib/typesafe-config.jar

.PHONY: build
build: make-avian $(stage2).d $(build)/scala

.PHONY: make-avian
make-avian:
	(cd $(avian) && make arch=$(arch) platform=$(platform) \
		"openjdk=$(openjdk)" "openjdk-src=$(openjdk-src)" bootimage=$(bootimage) \
		$(avian-targets))

$(stage1).d: $(jars)
	@rm -rf $(stage1)
	mkdir -p $(stage1)
	(cd build/stage1 && for jar in $(^); do jar xf $${jar}; done)
	@touch $(@)

$(avian-objects-dep):
	@mkdir -p $(build)/avian-objects
	(cd $(build)/avian-objects && ar x $(avian-build)/libavian.a)
	@touch $(@)

$(build)/resources.jar: $(resources).d
	cd $(resources) && jar cf $(build)/resources.jar *

$(build)/resources-jar.o: $(build)/resources.jar
	$(converter) $(<) $(@) _binary_resources_jar_start \
		_binary_resources_jar_end $(platform) $(arch) 1

$(build)/%.o: $(src)/%.cpp
	@mkdir -p $(dir $(@))
	$(cxx) $(cflags) -c $(<) -o $(@)

$(stage2).d: $(stage1).d
	@mkdir -p $(dir $(@))
	rm -rf $(stage2)
ifeq ($(run-proguard),true)
	$(java) -jar $(proguard) \
		-injars $(stage1) \
		-outjars $(stage2) \
		-dontusemixedcaseclassnames \
		-dontwarn \
		-dontoptimize \
		-dontobfuscate \
		@$(avian)/vm.pro \
		$(proguard-flags) \
		@scala.pro
else
	mkdir -p $(stage2)
	cp -r $(stage1)/* $(stage2)
endif
	@touch $(@)

$(resources).d: $(stage2).d
	@mkdir -p $(dir $(@))
	rm -rf $(resources)
	mkdir -p $(resources)
	cd $(stage2) && find . -type f -not -name '*.class' \
		| xargs tar cf - | tar xf - -C $(resources)
	@touch $(@)

$(bootimage-object): $(stage2).d
	$(bootimage-generator) -cp $(stage2) -bootimage $(@) \
		-codeimage $(codeimage-object)

$(boot-jar): $(stage2).d
	cd $(stage2) && jar cf $(boot-jar) *

$(boot-object): $(boot-jar)
	$(converter) $(<) $(@) _binary_boot_jar_start \
		_binary_boot_jar_end $(platform) $(arch) 1

$(build)/scala: $(objects) $(avian-objects-dep)
	$(cc) $(objects) $(build)/avian-objects/*.o -rdynamic $(lflags) -o $(@)

.PHONY: clean
clean:
	rm -rf $(build)
