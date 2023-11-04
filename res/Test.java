package res;

public class Test {
    @SuppressWarnings("unused")
    public static void main(String[] args) {
        final String s1 = "some string";
        String s2 = "some other string";
        String s3 = s1 + s2;

        Runnable r = () -> System.out.println(new InnerClass());

        System.out.println(InnerClass.MASK);
        InnerClass inner = new InnerClass();
        System.out.println(inner.somethingElse);
        System.out.println(inner.someConstantDouble);
        System.out.println(inner.someConstantLong);
    }

    static class InnerClass {
        static final int MASK = 0x21;
        final float somethingElse = Float.NEGATIVE_INFINITY;
        final double someConstantDouble = 3.14;
        final long someConstantLong = -100004L;

        @SuppressWarnings("unused")
        private transient float a;
    }

    public interface SomeInterface {
        void foo();
    }

    class SomeClass implements SomeInterface {
        @Override
        public void foo() {
            System.out.println(InnerClass.MASK);
        }

        @Deprecated
        native void i_ret();
    }
}