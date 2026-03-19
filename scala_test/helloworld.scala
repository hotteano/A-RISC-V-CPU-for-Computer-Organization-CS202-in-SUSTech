// 1. 单例对象（类似 Java 的 static）
object HelloWorld {
  
  // 2. main 方法 - 程序入口
  def main(args: Array[String]): Unit = {
    println("Hello, World!")           // 3. 打印（自动换行）
    print("No newline")                //    不换行
    println(s"\n你好，${args(0)}!")    // 4. 字符串插值
    
    // 5. 变量声明
    val immutable = "不可变"            // val = final（推荐）
    var mutable = 42                    // var = 可变
    mutable = 100                       // OK
    // immutable = "xxx"                // 编译错误！
    
    // 6. 类型推断（编译器自动推导）
    val number = 123        // Int
    val text = "abc"        // String
    val pi = 3.14           // Double
    
    // 7. 显式声明类型
    val explicit: Long = 10000000000L
    
    // 8. 函数定义
    def add(a: Int, b: Int): Int = a + b
    val result = add(10, 20)
    println(s"10 + 20 = $result")
    
    // 9. 代码块返回最后一条语句的值
    val blockResult = {
      val x = 10
      val y = 20
      x + y  // 返回值（不需要 return）
    }
    println(s"代码块结果: $blockResult")
    
    // 10. 条件表达式（有返回值）
    val max = if (result > 15) result else 15
    println(s"max = $max")
    
    // 11. for 循环
    println("for 循环:")
    for (i <- 1 to 3) {
      println(s"  i = $i")
    }
    
    // 12. 函数式风格：遍历集合
    val list = List(1, 2, 3, 4, 5)
    val doubled = list.map(_ * 2)           // 每个元素乘2
    val evens = list.filter(_ % 2 == 0)     // 过滤偶数
    val sum = list.sum                      // 求和
    
    println(s"原列表: $list")
    println(s"乘2后: $doubled")
    println(s"偶数: $evens")
    println(s"求和: $sum")
  }
}
