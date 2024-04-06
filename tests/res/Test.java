public class Test {
	final int i = 2;

    public Test(int i) {}

	public int getI() { return i; }

    public static void main(String[] args) {
        Test t = new Test(2);
        t.getI();
    }
}
