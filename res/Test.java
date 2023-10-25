package res;

public class Test {
    @SuppressWarnings("unused")
    public static void main(String[] args) {
        String s1 = "some string";
        String s2 = "some other string";
        String s3 = s1 + s2;

        Runnable r = () -> System.out.println(new InnerClass());
    }


    static class InnerClass {
        static final int MASK = 0x2;

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