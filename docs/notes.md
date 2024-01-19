# Notes for myself

## String Concatenations

When doing string concatenations, the following entries can be found in the constant pool:
```
  #49 = String             #50            // \u0001\u0001
  #50 = Utf8               \u0001\u0001
```

The char `\u0001` represents an argument and is used because javac translates the following:
```java
String s1 = "some str";
String s2 = "another one";
String s3 = s1 + s2;
```

to roughly `format("\u0001\u0001", s1, s2)`. Also occurrences of `StringConcatFactory.makeConcatWithConstants` can be found in the constant pool.

Remember that javac doesn't optimize much and the JIT compiler will do the heavy work.

## Important Attributes

Seven attributes are critical to correct implementation of a class file by the JVM:

- ConstantValue
- Code
- StackMapTable
- BootstrapMethods
- NestHost
- NestMembers
- PermittedSubclasses

Ten attributes are not critical to correct interpretation of the class file by the Java Virtual Machine, but are either critical to correct interpretation of the class file by the class libraries of the Java SE Platform, or are useful for tools (in which case the section that specifies an attribute describes it as "optional"):

- Exceptions
- InnerClasses
- EnclosingMethod
- Synthetic
- Signature
- Record
- SourceFile
- LineNumberTable
- LocalVariableTable
- LocalVariableTypeTable

Thirteen attributes are not critical to correct interpretation of the class file by the Java Virtual Machine, but contain metadata about the class file that is either exposed by the class libraries of the Java SE Platform, or made available by tools (in which case the section that specifies an attribute describes it as "optional"):

- SourceDebugExtension
- Deprecated
- RuntimeVisibleAnnotations
- RuntimeInvisibleAnnotations
- RuntimeVisibleParameterAnnotations
- RuntimeInvisibleParameterAnnotations
- RuntimeVisibleTypeAnnotations
- RuntimeInvisibleTypeAnnotations
- AnnotationDefault
- MethodParameters
- Module
- ModulePackages
- ModuleMainClass

`~ source: https://cr.openjdk.org/~dlsmith/jep181/nestmates.html`
