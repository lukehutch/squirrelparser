void main() {
  final input = '{"name":@@@,"age":30,"active":true,"scores":[95,87,92]}';
  for (int i = 0; i < input.length; i++) {
    print('$i: ${input[i]}');
  }
  print('\nError ranges:');
  print('pos=8 len=3: "${input.substring(8, 11)}"');
  print('pos=20 len=25: "${input.substring(20, 45)}"');
  print('pos=47 len=1: "${input.substring(47, 48)}"');
  print('pos=51 len=3: "${input.substring(51, 54)}"');
}
