import 'dart:io';
import 'package:http/http.dart' as http;

bool isNetworkError(Object error) =>
    error is SocketException || error is http.ClientException;

String friendlyErrorMessage(Object error) {
  if (isNetworkError(error)) {
    return 'Unable to reach the server. Check your connection and try again.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
