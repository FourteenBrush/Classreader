# Classreader
A Java class-file reader

*Under progress..*

## Usage

```
classreader.exe /path/to/some/class/file
```

## Sample output:

```
class name: res/Test
minor version: 0
major version: 63
access flags: 0x21 (ACC_PUBLIC, ACC_SUPER)
Constant pool:
   #1 = MethodRef          java/lang/Object.<init>
   #2 = Class              java/lang/Object
   #3 = NameAndType        <init>:()V
   #4 = Utf8               java/lang/Object
   #5 = Utf8               <init>
   #6 = Utf8               ()V
   #7 = String             some string
   #8 = Utf8               some string
   #9 = String             some other string
  #10 = Utf8               some other string
  #11 = InvokeDynamic      #0:makeConcatWithConstants:(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
  #12 = NameAndType        makeConcatWithConstants:(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
  #13 = Utf8               makeConcatWithConstants
  #14 = Utf8               (Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
  #15 = InvokeDynamic      #1:run:()Ljava/lang/Runnable;
  #16 = NameAndType        run:()Ljava/lang/Runnable;
  #17 = Utf8               run
  #18 = Utf8               ()Ljava/lang/Runnable;
  #19 = FieldRef           java/lang/System.out
  #20 = Class              java/lang/System
  #21 = NameAndType        out:Ljava/io/PrintStream;
  #22 = Utf8               java/lang/System
  #23 = Utf8               out
  #24 = Utf8               Ljava/io/PrintStream;
  #25 = Class              res/Test$InnerClass
  #26 = Utf8               res/Test$InnerClass
  #27 = MethodRef          res/Test$InnerClass.<init>
  #28 = MethodRef          java/io/PrintStream.println
  #29 = Class              java/io/PrintStream
  #30 = NameAndType        println:(Ljava/lang/Object;)V
  #31 = Utf8               java/io/PrintStream
  #32 = Utf8               println
  #33 = Utf8               (Ljava/lang/Object;)V
  #34 = Class              res/Test
  #35 = Utf8               res/Test
  #36 = Utf8               Code
  #37 = Utf8               LineNumberTable
  #38 = Utf8               main
  #39 = Utf8               ([Ljava/lang/String;)V
  #40 = Utf8               lambda$main$0
  #41 = Utf8               SourceFile
  #42 = Utf8               Test.java
  #43 = Utf8               NestMembers
  #44 = Class              res/Test$SomeClass
  #45 = Utf8               res/Test$SomeClass
  #46 = Class              res/Test$SomeInterface
  #47 = Utf8               res/Test$SomeInterface
  #48 = Utf8               BootstrapMethods
  #49 = MethodHandle       java/lang/invoke/StringConcatFactory.makeConcatWithConstants
  #50 = MethodRef          java/lang/invoke/StringConcatFactory.makeConcatWithConstants
  #51 = Class              java/lang/invoke/StringConcatFactory
  #52 = NameAndType        makeConcatWithConstants:(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/invoke/CallSite;
  #53 = Utf8               java/lang/invoke/StringConcatFactory
  #54 = Utf8               (Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/invoke/CallSite;
  #55 = String             ☺☺
  #56 = Utf8               ☺☺
  #57 = MethodHandle       java/lang/invoke/LambdaMetafactory.metafactory
  #58 = MethodRef          java/lang/invoke/LambdaMetafactory.metafactory
  #59 = Class              java/lang/invoke/LambdaMetafactory
  #60 = NameAndType        metafactory:(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodHandle;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/CallSite;
  #61 = Utf8               java/lang/invoke/LambdaMetafactory
  #62 = Utf8               metafactory
  #63 = Utf8               (Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodHandle;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/CallSite;
  #64 = MethodType         ()V
  #65 = MethodHandle       res/Test.lambda$main$0
  #66 = MethodRef          res/Test.lambda$main$0
  #67 = NameAndType        lambda$main$0:()V
  #68 = Utf8               InnerClasses
  #69 = Utf8               InnerClass
  #70 = Utf8               SomeClass
  #71 = Utf8               SomeInterface
  #72 = Class              java/lang/invoke/MethodHandles$Lookup
  #73 = Utf8               java/lang/invoke/MethodHandles$Lookup
  #74 = Class              java/lang/invoke/MethodHandles
  #75 = Utf8               java/lang/invoke/MethodHandles
  #76 = Utf8               Lookup
Attributes:
SourceFile
NestMembers
BootstrapMethods
InnerClasses
  ```

## Building yourself

- Make sure you have the Odin compiler installed (instructions on how to do so can be found
[here](https://odin-lang.org/docs/install/))

- Run the following command:
```
odin build src --out=classreader.exe
```
