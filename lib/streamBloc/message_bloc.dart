import 'dart:async';
import 'bloc_base.dart';

class MessageBloc extends BlocBase {
  final _controller = StreamController<dynamic>();
  get _msg => _controller.sink;
  get msg => _controller.stream;

  void increment(dynamic count) {
    _msg.add(count);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
