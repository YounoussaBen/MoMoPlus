class EarningItem {
  final String id;
  final String borrowerName;
  final double loanAmount;
  final double earned;
  final DateTime? completedAt;

  const EarningItem({
    required this.id,
    required this.borrowerName,
    required this.loanAmount,
    required this.earned,
    this.completedAt,
  });

  factory EarningItem.fromJson(Map<String, dynamic> json) {
    return EarningItem(
      id: json['id'] as String,
      borrowerName: json['borrower_name'] as String,
      loanAmount: double.parse(json['loan_amount'].toString()),
      earned: double.parse(json['earned'].toString()),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

class AgentEarnings {
  final double totalEarned;
  final int totalLoansCompleted;
  final double todayEarned;
  final int todayCount;
  final double thisWeekEarned;
  final int thisWeekCount;
  final double thisMonthEarned;
  final int thisMonthCount;
  final List<EarningItem> recentEarnings;

  const AgentEarnings({
    required this.totalEarned,
    required this.totalLoansCompleted,
    required this.todayEarned,
    required this.todayCount,
    required this.thisWeekEarned,
    required this.thisWeekCount,
    required this.thisMonthEarned,
    required this.thisMonthCount,
    required this.recentEarnings,
  });

  factory AgentEarnings.fromJson(Map<String, dynamic> json) {
    return AgentEarnings(
      totalEarned: double.parse(json['total_earned'].toString()),
      totalLoansCompleted: json['total_loans_completed'] as int,
      todayEarned: double.parse(json['today_earned'].toString()),
      todayCount: json['today_count'] as int,
      thisWeekEarned: double.parse(json['this_week_earned'].toString()),
      thisWeekCount: json['this_week_count'] as int,
      thisMonthEarned: double.parse(json['this_month_earned'].toString()),
      thisMonthCount: json['this_month_count'] as int,
      recentEarnings: (json['recent_earnings'] as List)
          .map((e) => EarningItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
