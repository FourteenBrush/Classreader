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
   #1 = MethodRef       java/lang/Object.<init>
   #2 = Class       java/lang/Object
   #3 = NameAndType       <init>:()V
   #4 = Utf8       java/lang/Object
   #5 = Utf8       <init>
   #6 = Utf8       ()V
   #7 = FieldRef       java/lang/System.out
   #8 = Class       java/lang/System
   #9 = NameAndType       out:Ljava/io/PrintStream;
  #10 = Utf8       java/lang/System
  #11 = Utf8       out
  #12 = Utf8       Ljava/io/PrintStream;
  #13 = String       Hello World
  #14 = Utf8       Hello World
  #15 = MethodRef       java/io/PrintStream.println
  #16 = Class       java/io/PrintStream
  #17 = NameAndType       println:(Ljava/lang/String;)V
  #18 = Utf8       java/io/PrintStream
  #19 = Utf8       println
  #20 = Utf8       (Ljava/lang/String;)V
  #21 = Class       Test
  #22 = Utf8       Test
  #23 = Utf8       Code
  #24 = Utf8       LineNumberTable
  #25 = Utf8       main
  #26 = Utf8       ([Ljava/lang/String;)V
  #27 = Utf8       SourceFile
  #28 = Utf8       Test.java
  ```

## Building yourself

- Make sure you have the Odin compiler installed (instructions on how to do some can be found
[here](https://odin-lang.org/docs/install/))

- Run the following command:
```
odin build --out=classreader.exe src
```
