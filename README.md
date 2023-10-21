# Classreader
A Java class-file reader

*Under progress..*

## Usage

```
classreader.exe /path/to/some/class/file
```

## Sample output:

```
class name: Test
minor version: 0
major version: 63
access flags: 0x21 (ACC_PUBLIC)
Constant pool:
   #1 = MethodRef          java/lang/Object.<init>
   #2 = Class              java/lang/Object
   #3 = NameAndType        <init>:()V
   #4 = Utf8               java/lang/Object
   #5 = Utf8               <init>
   #6 = Utf8               ()V
   #7 = Double             4614838538166547251
   #9 = Double             4610785298501913805
  #11 = FieldRef           java/lang/System.out
  #12 = Class              java/lang/System
  #13 = NameAndType        out:Ljava/io/PrintStream;
  #14 = Utf8               java/lang/System
  #15 = Utf8               out
  #16 = Utf8               Ljava/io/PrintStream;
  #17 = MethodRef          java/io/PrintStream.println
  #18 = Class              java/io/PrintStream
  #19 = NameAndType        println:(D)V
  #20 = Utf8               java/io/PrintStream
  #21 = Utf8               println
  #22 = Utf8               (D)V
  #23 = String             some string
  #24 = Utf8               some string
  #25 = String             some other string
  #26 = Utf8               some other string
  #27 = MethodRef          java/io/PrintStream.println
  #28 = NameAndType        println:(Ljava/lang/String;)V
  #29 = Utf8               (Ljava/lang/String;)V
  #30 = InvokeDynamic      todo
  #31 = NameAndType        makeConcatWithConstants:(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
  #32 = Utf8               makeConcatWithConstants
  #33 = Utf8               (Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
  #34 = Class              res/Test
  #35 = Utf8               res/Test
  #36 = Utf8               Code
  #37 = Utf8               LineNumberTable
  #38 = Utf8               main
  #39 = Utf8               ([Ljava/lang/String;)V
  #40 = Utf8               SourceFile
  #41 = Utf8               Test.java
  #42 = Utf8               BootstrapMethods
  #43 = MethodHandle       java/lang/invoke/StringConcatFactory.makeConcatWithConstants
  #44 = MethodRef          java/lang/invoke/StringConcatFactory.makeConcatWithConstants
  #45 = Class              java/lang/invoke/StringConcatFactory
  #46 = NameAndType        makeConcatWithConstants:(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/invoke/CallSite;     
  #47 = Utf8               java/lang/invoke/StringConcatFactory
  #48 = Utf8               (Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/invoke/CallSite;
  #49 = String             ☺☺
  #50 = Utf8               ☺☺
  #51 = Utf8               InnerClasses
  #52 = Class              java/lang/invoke/MethodHandles$Lookup
  #53 = Utf8               java/lang/invoke/MethodHandles$Lookup
  #54 = Class              java/lang/invoke/MethodHandles
  #55 = Utf8               java/lang/invoke/MethodHandles
  #56 = Utf8               Lookup
  ```

## Building yourself

- Make sure you have the Odin compiler installed (instructions on how to do so can be found
[here](https://odin-lang.org/docs/install/))

- Run the following command:
```
odin build src --out=classreader.exe
```
