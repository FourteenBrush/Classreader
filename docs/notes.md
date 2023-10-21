# Notes for myself

## String concatenations

When doing string concatenations, the following entries can be found in the constant pool:
```
  #49 = String             #50            // \u0001\u0001
  #50 = Utf8               \u0001\u0001
```

The char `\u0001` represents an argument and are used because javac translates the following:
```java
String s1 = "some str";
String s2 = "another one";
String s3 = s1 + s2;
```

to roughly `format("\u0001\u0001", s1, s2)`. Also occurrences of `StringConcatFactory.makeConcatWithConstants` can be found in the constant pool.

Remember that javac doesn't optimize and the JIT compiler will do the heavy work.