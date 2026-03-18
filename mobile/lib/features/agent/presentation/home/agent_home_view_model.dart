import 'package:flutter/material.dart';
import '../../../../core/data/repositories/auth_repository.dart';

class AgentHomeViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  bool _isLoading = false;

  AgentHomeViewModel(this._authRepository);

  bool get isLoading => _isLoading;

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
