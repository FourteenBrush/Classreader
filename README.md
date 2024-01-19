# Classreader
A Java class-file reader

*Under progress..*

## Usage

```
classreader SomeJavaFile.class
```

## Sample output:

```
Version: minor=0, major=65 (Java SE 21)
Access flags: 0x0021 (ACC_PUBLIC, ACC_SUPER)
Constant pool:
   #1 = MethodRef          java/lang/Object.<init>
   #2 = Class              java/lang/Object
   #3 = NameAndType        <init>:()V
   #4 = Utf8               java/lang/Object
   #5 = Utf8               <init>
   #6 = Utf8               ()V
   #7 = FieldRef           Test.i
   #8 = Class              Test
   #9 = NameAndType        i:I
  #10 = Utf8               Test
  #11 = Utf8               i
  #12 = Utf8               I
  #13 = FieldRef           Test.s
  #14 = NameAndType        s:Ljava/lang/String;
  #15 = Utf8               s
  #16 = Utf8               Ljava/lang/String;
  #17 = Utf8               ConstantValue
  #18 = Integer            2
  #19 = Utf8               (Ljava/lang/String;)V
  #20 = Utf8               Code
  #21 = Utf8               LineNumberTable
  #22 = Utf8               (I)V
  #23 = Utf8               getI
  #24 = Utf8               ()I
  #25 = Utf8               getS
  #26 = Utf8               ()Ljava/lang/String;
  #27 = Utf8               SourceFile
  #28 = Utf8               Test.java
Attributes:
  SourceFile
```

## Building the project

- Make sure you got the [Task build system](https://taskfile.dev/installation/) and the [Odin compiler](https://odin-lang.org/docs/install/) installed.
- Build with `task` or run `task -l` to show all available options
