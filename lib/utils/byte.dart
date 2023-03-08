List<int> tobyte(String str) {
  List<int> bytes = [];
  for (var i = 0; i < str.length; i++) {
    bytes.add(str.codeUnitAt(i));
  }
  return bytes;
}