import 'package:flutter/material.dart';
import '../../../../core/data/services/backend_api_service.dart';
import '../../../../core/utils/error_helpers.dart';
import '../../domain/agent_earnings.dart';

enum AgentEarningsPeriod {
  today('today'),
  week('week'),
  month('month'),
  custom('custom');

  const AgentEarningsPeriod(this.apiValue);

  final String apiValue;
}

class AgentEarningsViewModel extends ChangeNotifier {
  final BackendApiService _api;

  AgentEarnings? _earnings;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  AgentEarningsPeriod? _selectedPeriod;
  DateTimeRange? _customRange;

  AgentEarningsViewModel(this._api);

  AgentEarnings? get earnings => _earnings;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  AgentEarningsPeriod? get selectedPeriod => _selectedPeriod;
  DateTimeRange? get customRange => _customRange;

  Future<void> loadEarnings() async {
    await _fetchEarnings(period: _selectedPeriod, customRange: _customRange);
  }

  Future<void> togglePeriod(AgentEarningsPeriod period) async {
    final nextPeriod = _selectedPeriod == period ? null : period;
    await _fetchEarnings(
      period: nextPeriod,
      customRange: null,
      previewSelection: true,
    );
  }

  Future<void> selectCustomRange(DateTimeRange range) async {
    await _fetchEarnings(
      period: AgentEarningsPeriod.custom,
      customRange: _normalizeRange(range),
      previewSelection: true,
    );
  }

  Future<void> clearFilter() async {
    await _fetchEarnings(
      period: null,
      customRange: null,
      previewSelection: true,
    );
  }

  DateTimeRange _normalizeRange(DateTimeRange range) {
    return DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day),
    );
  }

  Future<void> _fetchEarnings({
    required AgentEarningsPeriod? period,
    required DateTimeRange? customRange,
    bool previewSelection = false,
  }) async {
    if (_isLoading || _isRefreshing) return;

    final previousPeriod = _selectedPeriod;
    final previousCustomRange = _customRange;
    final hasCachedData = _earnings != null;

    if (previewSelection) {
      _selectedPeriod = period;
      _customRange = customRange;
    }

    _isLoading = !hasCachedData;
    _isRefreshing = hasCachedData;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getAgentEarnings(
        period: period?.apiValue,
        startDate: customRange?.start,
        endDate: customRange?.end,
      );
      if (data != null) {
        _earnings = AgentEarnings.fromJson(data);
        _selectedPeriod = period;
        _customRange = customRange;
      } else if (previewSelection) {
        _selectedPeriod = previousPeriod;
        _customRange = previousCustomRange;
      }
    } catch (e) {
      if (previewSelection) {
        _selectedPeriod = previousPeriod;
        _customRange = previousCustomRange;
      }
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
