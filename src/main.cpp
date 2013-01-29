#include <stdint.h>
#include <stdlib.h>
#include <jni.h>

#if (defined __MINGW32__) || (defined _MSC_VER)
#  define EXPORT __declspec(dllexport)
#else
#  define EXPORT __attribute__ ((visibility("default"))) \
  __attribute__ ((used))
#endif

#if (! defined __x86_64__) && ((defined __MINGW32__) || (defined _MSC_VER))
#  define SYMBOL(x) x
#else
#  define SYMBOL(x) _##x
#endif

extern "C" {

void __cxa_pure_virtual(void) { abort(); }

#ifdef BOOT_IMAGE

#define BOOTIMAGE_BIN(x) SYMBOL(binary_bootimage_bin_##x)
#define CODEIMAGE_BIN(x) SYMBOL(binary_codeimage_bin_##x)

extern const uint8_t BOOTIMAGE_BIN(start)[];
extern const uint8_t BOOTIMAGE_BIN(end)[];

EXPORT const uint8_t*
bootimageBin(unsigned* size)
{
  *size = BOOTIMAGE_BIN(end) - BOOTIMAGE_BIN(start);
  return BOOTIMAGE_BIN(start);
}

extern const uint8_t CODEIMAGE_BIN(start)[];
extern const uint8_t CODEIMAGE_BIN(end)[];

EXPORT const uint8_t*
codeimageBin(unsigned* size)
{
  *size = CODEIMAGE_BIN(end) - CODEIMAGE_BIN(start);
  return CODEIMAGE_BIN(start);
}

#ifdef RESOURCES

#define RESOURCES_JAR(x) SYMBOL(binary_resources_jar_##x)

extern const uint8_t RESOURCES_JAR(start)[];
extern const uint8_t RESOURCES_JAR(end)[];

EXPORT const uint8_t*
resourcesJar(unsigned* size)
{
  *size = RESOURCES_JAR(end) - RESOURCES_JAR(start);
  return RESOURCES_JAR(start);
}

#endif // RESOURCES

#elif (! defined RUNTIME_CLASSPATH)

#define BOOT_JAR(x) SYMBOL(binary_boot_jar_##x)

extern const uint8_t BOOT_JAR(start)[];
extern const uint8_t BOOT_JAR(end)[];

EXPORT const uint8_t*
bootJar(unsigned* size)
{
  *size = BOOT_JAR(end) - BOOT_JAR(start);
  return BOOT_JAR(start);
}

#endif // not BOOT_IMAGE

} // extern "C"

int
main(int ac, const char** av)
{
  JavaVMInitArgs vmArgs;
  vmArgs.version = JNI_VERSION_1_2;
  vmArgs.nOptions = 3;
  vmArgs.ignoreUnrecognized = JNI_TRUE;

  JavaVMOption options[vmArgs.nOptions];
  vmArgs.options = options;

  options[0].optionString = const_cast<char*>
    ("-Davian.bootimage=bootimageBin");

  options[1].optionString = const_cast<char*>
    ("-Davian.codeimage=codeimageBin");

#ifdef RUNTIME_CLASSPATH
  if (ac < 2) {
    fprintf(stderr, "usage: %s <classpath> [scala arguments]\n", av[0]);
    return -1;
  }

  unsigned length = 256;
  char buffer[length];
  snprintf(buffer, length, "-Xbootclasspath:%s", av[1]);
  options[2].optionString = buffer;
  unsigned start = 2;
#else
  options[2].optionString = const_cast<char*>
    ("-Xbootclasspath:[bootJar]:[resourcesJar]");
  unsigned start = 1;
#endif

  JavaVM* vm;
  void* env;
  JNI_CreateJavaVM(&vm, &env, &vmArgs);
  JNIEnv* e = static_cast<JNIEnv*>(env);

  jclass c = e->FindClass(MAIN_CLASS);
  if (not e->ExceptionCheck()) {
    jmethodID m = e->GetStaticMethodID(c, "main", "([Ljava/lang/String;)V");
    if (not e->ExceptionCheck()) {
      jclass stringClass = e->FindClass("java/lang/String");
      if (not e->ExceptionCheck()) {
        jobjectArray a = e->NewObjectArray(ac - start, stringClass, 0);
        if (not e->ExceptionCheck()) {
          for (int i = start; i < ac; ++i) {
            e->SetObjectArrayElement(a, i - start, e->NewStringUTF(av[i]));
          }

          e->CallStaticVoidMethod(c, m, a);
        }
      }
    }
  }

  int exitCode = 0;
  if (e->ExceptionCheck()) {
    exitCode = -1;
    e->ExceptionDescribe();
  }

  vm->DestroyJavaVM();

  return exitCode;
}
