import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const TollgateApp());
}

// --- CONFIGURATION ---
class EngineConfig {
  static const double maxAcceptablePrice = 0.20;
  static const double maxAcceptableLatencyMs = 200.0;
  
  static const double priceWeight = 0.40;
  static const double latencyWeight = 0.30;
  static const double reliabilityWeight = 0.30;
  
  static const double budgetOverageMargin = 2.00;
}

class TollgateApp extends StatelessWidget {
  const TollgateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tollgate Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          secondary: Colors.blueAccent,
          surface: Colors.grey[50]!,
        ),
        fontFamily: 'Roboto', 
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFFEEEEEE), width: 1),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const TollgateDashboard(),
    );
  }
}

// --- STATE MANAGEMENT ---

class DemoState extends ChangeNotifier {
  bool isRunning = false;
  bool isReplaying = false;
  bool summaryShown = false; 
  int currentStepIndex = -1;
  
  final List<String> steps = ['Search', 'Extract', 'Translate', 'Rank', 'Deliver'];
  List<String> stepStatuses = ['Queued', 'Queued', 'Queued', 'Queued', 'Queued'];
  
  // Treasury & Execution State
  double totalBudget = 10.00;
  double spent = 0.00;
  double reserved = 0.00;
  double currentStepCost = 0.0;
  double totalOverageApproved = 0.0;
  
  int totalExecutionAttempts = 0;
  int successfulExecutions = 0;
  int duplicatesBlocked = 0;
  
  // Deterministic Event Sequencing
  int eventSequence = 0;
  
  String nextEventId(String prefix) {
    eventSequence++;
    return '$prefix-${eventSequence.toString().padLeft(6, '0')}';
  }

  // Idempotency State
  Set<String> processedIdempotencyKeys = {};
  String currentIdempotencyKey = "";
  
  // Explicit Simulated Provider Profiles
  List<Map<String, dynamic>> providers = [
    {'name': 'Provider A', 'status': 'Online', 'price': 0.12, 'latency': 120, 'reliability': 0.99},
    {'name': 'Provider B', 'status': 'Online', 'price': 0.10, 'latency': 140, 'reliability': 0.95},
    {'name': 'Provider C', 'status': 'Online', 'price': 0.15, 'latency': 90,  'reliability': 0.999},
  ];
  
  Map<String, dynamic>? currentWinner;
  List<Map<String, dynamic>> lastScores = [];
  Map<String, String> policyStatus = {
    'Provider Availability': 'PENDING',
    'Budget Guardrail': 'PENDING',
    'Trust & Identity': 'PENDING',
  };
  
  List<Map<String, dynamic>> ledger = [];
  List<String> auditLog = ['System initialized.'];
  
  int paymentNodeIndex = -1;
  bool forceBudgetOverage = false;

  // --- DERIVED METRICS ---
  
  String get successRateStr {
    if (totalExecutionAttempts == 0) return "100%";
    return "${((successfulExecutions / totalExecutionAttempts) * 100).toStringAsFixed(1)}%";
  }

  String get budgetAdherenceStr {
    if (totalOverageApproved <= 0) return "100%";
    double adherence = max(0.0, 100.0 - ((totalOverageApproved / totalBudget) * 100));
    return "${adherence.toStringAsFixed(1)}%";
  }
  
  String get activeProvidersStr {
    int activeCount = providers.where((p) => p['status'] == 'Online').length;
    return "$activeCount/${providers.length}";
  }

  double get availableBalance => totalBudget - spent - reserved;
  
  int get failedOrNoChargeExecutions => totalExecutionAttempts - successfulExecutions - duplicatesBlocked;

  void logEvent(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    auditLog.insert(0, "$time — $message");
    notifyListeners();
  }

  void startTask() {
    if (isRunning) return;
    resetDemo();
    isRunning = true;
    currentStepIndex = 0;
    logEvent("Task started.");
    _processStep();
  }

  void _processStep() async {
    if (currentStepIndex >= steps.length) {
      isRunning = false;
      logEvent("Task completed successfully.");
      notifyListeners();
      return;
    }

    stepStatuses[currentStepIndex] = 'Routing';
    currentWinner = null;
    lastScores.clear();
    policyStatus = {
      'Provider Availability': 'EVALUATING...',
      'Budget Guardrail': 'PENDING',
      'Trust & Identity': 'PENDING',
    };
    
    currentIdempotencyKey = nextEventId("IDEM");
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));

    // Policy Gate 1: Availability
    var available = providers.where((p) => p['status'] == 'Online').toList();
    if (available.isEmpty) {
      stepStatuses[currentStepIndex] = 'Failed';
      policyStatus['Provider Availability'] = 'FAIL';
      logEvent("Task failed — Policy violation: No providers available.");
      isRunning = false;
      notifyListeners();
      return;
    }
    policyStatus['Provider Availability'] = 'PASS';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    
    // --- MULTI-FACTOR ROUTING ALGORITHM ---
    for (var p in available) {
      double priceScore = max(0, 1.0 - (p['price'] / EngineConfig.maxAcceptablePrice)); 
      double latencyScore = max(0, 1.0 - (p['latency'] / EngineConfig.maxAcceptableLatencyMs));
      double relScore = p['reliability'];

      double totalScore = (priceScore * EngineConfig.priceWeight) + 
                          (latencyScore * EngineConfig.latencyWeight) + 
                          (relScore * EngineConfig.reliabilityWeight);
      
      lastScores.add({
        'name': p['name'],
        'price': p['price'],
        'latency': p['latency'],
        'rawPriceScore': priceScore * 100,
        'rawLatencyScore': latencyScore * 100,
        'rawRelScore': relScore * 100,
        'score': totalScore * 100,
      });
    }

    lastScores.sort((a, b) => b['score'].compareTo(a['score']));
    currentWinner = available.firstWhere((p) => p['name'] == lastScores.first['name']);
    
    String reason = "Highest composite score (${lastScores.first['score'].toStringAsFixed(1)}/100). ";
    double minPrice = available.map((p) => p['price'] as double).reduce(min);
    if (lastScores.first['price'] == minPrice) reason += "Lowest cost. ";
    double minLatency = available.map((p) => (p['latency'] as num).toDouble()).reduce(min);
    if (lastScores.first['latency'] == minLatency) reason += "Lowest latency. ";
    
    currentWinner!['reason'] = reason.trim();
    
    logEvent("Route selected via multi-factor engine: ${currentWinner!['name']}");
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));

    // Policy Gate 2 & 3: Budget and Trust
    policyStatus['Trust & Identity'] = 'PASS';
    
    currentStepCost = forceBudgetOverage ? (availableBalance + EngineConfig.budgetOverageMargin) : currentWinner!['price'];
    
    if (spent + reserved + currentStepCost > totalBudget) {
      policyStatus['Budget Guardrail'] = 'WARN (EXCEEDED)';
      stepStatuses[currentStepIndex] = 'Awaiting Approval';
      notifyListeners();
      return; 
    }
    
    policyStatus['Budget Guardrail'] = 'PASS';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    _executePaymentSequence();
  }

  void _executePaymentSequence() async {
    // CAPTURE SYNCHRONOUS STATE BEFORE AWAITS TO PREVENT NULL ERRORS MID-FLIGHT
    final String activeProviderName = currentWinner?['name'] ?? 'Unknown';
    final int activeStepIndex = currentStepIndex;
    final String activeIdemKey = currentIdempotencyKey;
    
    // 1. Exact Idempotency Check
    totalExecutionAttempts++;
    if (processedIdempotencyKeys.contains(activeIdemKey)) {
      duplicatesBlocked++;
      ledger.insert(0, {
        'time': DateTime.now().toIso8601String().substring(11, 19),
        'step': steps[activeStepIndex],
        'provider': activeProviderName,
        'amount': 0.0,
        'status': 'Blocked – Duplicate',
        'eventId': nextEventId('BLK'),
        'idempotencyKey': activeIdemKey
      });
      logEvent("Duplicate request blocked (idempotency key reused).");
      notifyListeners();
      return; 
    }

    processedIdempotencyKeys.add(activeIdemKey);
    
    // 2. Exact Reservation Logic
    reserved += currentStepCost;
    logEvent("Budget reserved: \$${currentStepCost.toStringAsFixed(2)}");
    notifyListeners();
    
    // 3. Payment Protocol Visualizer Simulation
    for (int i = 0; i < 5; i++) {
      paymentNodeIndex = i;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    paymentNodeIndex = -1;

    // 4. Exact Settlement Logic
    if (currentStepCost == 0.0) return; 

    reserved -= currentStepCost;
    spent += currentStepCost;
    successfulExecutions++;
    
    ledger.insert(0, {
      'time': DateTime.now().toIso8601String().substring(11, 19),
      'step': steps[activeStepIndex],
      'provider': activeProviderName,
      'amount': currentStepCost,
      'status': 'Settled',
      'eventId': nextEventId('TX'),
      'idempotencyKey': activeIdemKey
    });
    
    stepStatuses[activeStepIndex] = 'Complete';
    logEvent("Settlement confirmed for ${steps[activeStepIndex]}");
    currentStepIndex++;
    notifyListeners();
    
    if (!isReplaying) {
      await Future.delayed(const Duration(milliseconds: 600));
      _processStep();
    }
  }

  void resolveApproval(bool approved) {
    forceBudgetOverage = false;
    if (approved) {
      double overage = (spent + reserved + currentStepCost) - totalBudget;
      if (overage > 0) totalOverageApproved += overage;
      
      logEvent("Manual override approved. Policy forced to PASS.");
      policyStatus['Budget Guardrail'] = 'PASS (OVERRIDE)';
      notifyListeners();
      _executePaymentSequence(); 
    } else {
      logEvent("Manual override denied. Step skipped.");
      currentStepCost = 0.0; 
      stepStatuses[currentStepIndex] = 'Skipped';
      currentStepIndex++;
      _processStep();
    }
  }

  void fireDuplicatePayment(BuildContext context) {
    if (!isRunning || currentStepIndex >= steps.length) return;
    
    _executePaymentSequence();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulated duplicate payload fired.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black),
    );
  }

  void killProvider(int index, BuildContext context) {
    providers[index]['status'] = 'Offline';
    logEvent("${providers[index]['name']} failure detected.");
    
    if (isRunning && currentWinner != null && currentWinner!['name'] == providers[index]['name']) {
       ScaffoldMessenger.of(context).showMaterialBanner(
         MaterialBanner(
           content: Text("${providers[index]['name']} unavailable mid-flight — rerouting. No funds lost."),
           backgroundColor: Colors.amber[100],
           actions: [
             TextButton(
               onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(), 
               child: const Text('DISMISS', style: TextStyle(color: Colors.black))
             )
           ],
         )
       );
       
       Future.delayed(const Duration(seconds: 3), () {
         ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
       });

       ledger.insert(0, {
          'time': DateTime.now().toIso8601String().substring(11, 19),
          'step': steps[currentStepIndex],
          'provider': providers[index]['name'],
          'amount': 0.0,
          'status': 'Failed – No Charge',
          'eventId': nextEventId('ERR'),
          'idempotencyKey': currentIdempotencyKey
       });
       
       reserved -= currentStepCost;
       if (reserved < 0) reserved = 0.0; 
       currentStepCost = 0.0; 
       totalExecutionAttempts++;
       
       _processStep(); 
    }
    notifyListeners();
  }

  void triggerBudgetCap() {
    forceBudgetOverage = true;
  }

  void replayLastRun() async {
    isReplaying = true;
    var oldLedger = List<Map<String, dynamic>>.from(ledger);
    resetDemo();
    logEvent("Replay mode engaged. Constructing state from events.");
    
    for (var entry in oldLedger.reversed) {
      ledger.insert(0, entry);
      
      if (entry['status'] == 'Settled') {
        spent += entry['amount'];
        successfulExecutions++;
      } else if (entry['status'] == 'Blocked – Duplicate') {
        duplicatesBlocked++;
      }
      totalExecutionAttempts++;
      
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    logEvent("Replay complete — ledger events reconstructed successfully.");
    isReplaying = false;
  }

  void resetDemo() {
    isRunning = false;
    isReplaying = false;
    summaryShown = false; 
    currentStepIndex = -1;
    stepStatuses = ['Queued', 'Queued', 'Queued', 'Queued', 'Queued'];
    
    spent = 0.0;
    reserved = 0.0;
    currentStepCost = 0.0;
    totalOverageApproved = 0.0;
    
    totalExecutionAttempts = 0;
    successfulExecutions = 0;
    duplicatesBlocked = 0;
    eventSequence = 0;
    
    processedIdempotencyKeys.clear();
    currentIdempotencyKey = "";
    
    providers = [
      {'name': 'Provider A', 'status': 'Online', 'price': 0.12, 'latency': 120, 'reliability': 0.99},
      {'name': 'Provider B', 'status': 'Online', 'price': 0.10, 'latency': 140, 'reliability': 0.95},
      {'name': 'Provider C', 'status': 'Online', 'price': 0.15, 'latency': 90,  'reliability': 0.999},
    ];
    
    ledger.clear();
    auditLog = ['System initialized.'];
    currentWinner = null;
    lastScores.clear();
    policyStatus = {
      'Provider Availability': 'PENDING',
      'Budget Guardrail': 'PENDING',
      'Trust & Identity': 'PENDING',
    };
    forceBudgetOverage = false;
    notifyListeners();
  }
}

// --- UI COMPONENTS ---

class TollgateDashboard extends StatefulWidget {
  const TollgateDashboard({super.key});

  @override
  State<TollgateDashboard> createState() => _TollgateDashboardState();
}

class _TollgateDashboardState extends State<TollgateDashboard> {
  final DemoState state = DemoState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        
        if (state.isRunning && state.currentStepIndex >= 0 && state.currentStepIndex < state.stepStatuses.length) {
           if (state.stepStatuses[state.currentStepIndex] == 'Awaiting Approval') {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (ModalRoute.of(context)?.isCurrent == true) {
                 _showApprovalDialog(context);
               }
             });
           }
        }

        if (!state.isRunning && state.currentStepIndex >= state.steps.length && !state.summaryShown) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (ModalRoute.of(context)?.isCurrent == true) {
                 state.summaryShown = true;
                 _showSummaryDialog(context);
               }
             });
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Tollgate',
              style: TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.0, 
              ),
            ),
            actions: [
              if (state.isReplaying)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                    child: const Center(child: Text("REPLAY MODE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                  ),
                )
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildControlBar(context),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - SCROLLABLE WRAPPER TO PREVENT OVERFLOW
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildKPIHeader(),
                            const SizedBox(height: 48),
                            _buildActiveTaskPanel(),
                            const SizedBox(height: 48),
                            _buildLivePaymentVisualizer(),
                            const SizedBox(height: 48),
                            _buildProviderGrid(context),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xFFEEEEEE)),
                    // Right Column - FLEXIBLE WRAPPERS ADDED
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTreasuryMeter(),
                            const SizedBox(height: 24),
                            if (state.currentWinner != null || state.isRunning) 
                              Flexible(
                                flex: 3, 
                                child: SingleChildScrollView(
                                  child: _buildDecisionEnginePanel()
                                )
                              ),
                            if (state.currentWinner != null || state.isRunning)
                              const SizedBox(height: 24),
                            Expanded(flex: 2, child: _buildLedger()),
                            const SizedBox(height: 16),
                            Expanded(flex: 2, child: _buildAuditTimeline()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      child: Wrap(
        spacing: 16,
        children: [
          ElevatedButton.icon(
            onPressed: state.isRunning ? null : () => state.startTask(),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text("Start Task"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
          ),
          OutlinedButton.icon(
            onPressed: state.isRunning ? () => state.fireDuplicatePayment(context) : null,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("Fire Duplicate Payment"),
          ),
          OutlinedButton.icon(
            onPressed: state.isRunning ? () => state.triggerBudgetCap() : null,
            icon: const Icon(Icons.warning_amber, size: 16),
            label: const Text("Push Budget Over Cap"),
          ),
          OutlinedButton.icon(
            onPressed: (!state.isRunning && state.ledger.isNotEmpty) ? () => state.replayLastRun() : null,
            icon: const Icon(Icons.replay, size: 16),
            label: const Text("Replay Last Run"),
          ),
          TextButton.icon(
            onPressed: () => state.resetDemo(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Reset Demo", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _kpiTile("Total Spend", "\$${state.spent.toStringAsFixed(2)}"),
        _kpiTile("Duplicates Blocked", "${state.duplicatesBlocked}"),
        _kpiTile("Success Rate", state.successRateStr),
        _kpiTile("Budget Adherence", state.budgetAdherenceStr),
        _kpiTile("Active Providers", state.activeProvidersStr),
      ],
    );
  }

  Widget _kpiTile(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
      ],
    );
  }

  Widget _buildActiveTaskPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ACTIVE TASK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(state.steps.length, (index) {
            bool isActive = state.currentStepIndex == index;
            String status = state.stepStatuses[index];
            Color nodeColor = Colors.grey[300]!;
            
            if (status == 'Complete') nodeColor = Colors.green;
            else if (status == 'Routing') nodeColor = Colors.blue;
            else if (status == 'Awaiting Approval') nodeColor = Colors.amber;
            else if (status == 'Failed') nodeColor = Colors.red;
            else if (status == 'Skipped') nodeColor = Colors.grey;

            return Expanded(
              child: Row(
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isActive ? 24 : 16,
                        height: isActive ? 24 : 16,
                        decoration: BoxDecoration(color: nodeColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(height: 12),
                      Text(state.steps[index], style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                      Text(status, style: TextStyle(fontSize: 10, color: nodeColor)),
                    ],
                  ),
                  if (index < state.steps.length - 1)
                    Expanded(child: Container(height: 2, color: Colors.grey[200])),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _statRow(String label, double rawScore) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(rawScore.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDecisionEnginePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("POLICY EVALUATION & ROUTING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: state.policyStatus.entries.map((entry) {
                Color statusColor = Colors.grey;
                if (entry.value.contains('PASS')) statusColor = Colors.green;
                if (entry.value.contains('WARN')) statusColor = Colors.amber;
                if (entry.value.contains('FAIL')) statusColor = Colors.red;
                if (entry.value.contains('EVAL')) statusColor = Colors.blue;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(entry.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                  ],
                );
              }).toList(),
            ),
            
            if (state.lastScores.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(height: 1, color: Color(0xFFEEEEEE)),
              ),
              
              const Text("EXPLICIT ROUTING MATHEMATICS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
              const SizedBox(height: 12),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                child: Text(
                  "Score = ${(EngineConfig.priceWeight).toStringAsFixed(2)}×PriceScore + ${(EngineConfig.latencyWeight).toStringAsFixed(2)}×LatencyScore + ${(EngineConfig.reliabilityWeight).toStringAsFixed(2)}×RelScore\n"
                  "PriceScore = max(0, 1 - price / ${EngineConfig.maxAcceptablePrice})\n"
                  "LatencyScore = max(0, 1 - latency / ${EngineConfig.maxAcceptableLatencyMs})",
                  style: const TextStyle(fontSize: 10, color: Colors.blue, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              if (state.currentWinner != null) ...state.lastScores.where((s) => s['name'] == state.currentWinner!['name']).map((winnerScore) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    border: Border.all(color: Colors.grey[300]!), 
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text("Winner Breakdown: ${winnerScore['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                       const SizedBox(height: 8),
                       _statRow("Price Score (${(EngineConfig.priceWeight * 100).toStringAsFixed(0)}%)", winnerScore['rawPriceScore']),
                       _statRow("Latency Score (${(EngineConfig.latencyWeight * 100).toStringAsFixed(0)}%)", winnerScore['rawLatencyScore']),
                       _statRow("Reliability Score (${(EngineConfig.reliabilityWeight * 100).toStringAsFixed(0)}%)", winnerScore['rawRelScore']),
                       const Divider(height: 16),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text("Weighted Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                           Text(winnerScore['score'].toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                         ]
                       )
                    ]
                  )
                );
              }),
              
              const SizedBox(height: 16),
              
              const Text("CANDIDATE RANKING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
              const SizedBox(height: 8),
              Column(
                children: state.lastScores.map((scoreCard) {
                  bool isWinner = state.currentWinner != null && state.currentWinner!['name'] == scoreCard['name'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(scoreCard['name'], style: TextStyle(fontWeight: isWinner ? FontWeight.bold : FontWeight.normal)),
                        Text("\$${scoreCard['price']} | ${scoreCard['latency']}ms", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(scoreCard['score'].toStringAsFixed(1), style: TextStyle(fontWeight: isWinner ? FontWeight.bold : FontWeight.normal, color: isWinner ? Colors.green : Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTreasuryMeter() {
    double spentPct = (state.spent / state.totalBudget).clamp(0.0, 1.0);
    double reservedPct = (state.reserved / state.totalBudget).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("TREASURY & BUDGET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
            Text("Available: \$${state.availableBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Flexible(flex: (spentPct * 100).toInt(), child: Container(color: Colors.black)),
              Flexible(flex: (reservedPct * 100).toInt(), child: Container(color: Colors.amber)),
              Flexible(flex: ((1 - spentPct - reservedPct) * 100).toInt(), child: Container(color: Colors.transparent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivePaymentVisualizer() {
    List<String> nodes = ['Request', '402', 'Signed', 'Verified', 'Settled'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Text("x402 PAYMENT LIFECYCLE (SIMULATED)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
         const SizedBox(height: 24),
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
           children: List.generate(nodes.length, (index) {
             bool isLit = state.paymentNodeIndex == index;
             return Column(
               children: [
                 AnimatedContainer(
                   duration: const Duration(milliseconds: 200),
                   width: 32,
                   height: 32,
                   decoration: BoxDecoration(
                     color: isLit ? Colors.green : Colors.white,
                     border: Border.all(color: isLit ? Colors.green : Colors.grey[300]!, width: 2),
                     borderRadius: BorderRadius.circular(8)
                   ),
                 ),
                 const SizedBox(height: 8),
                 Text(nodes[index], style: const TextStyle(fontSize: 10, color: Colors.grey)),
               ],
             );
           }),
         ),
      ],
    );
  }

  Widget _buildProviderGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("DYNAMIC PROVIDER PROFILES (SIMULATED)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(state.providers.length, (index) {
            var p = state.providers[index];
            bool isOnline = p['status'] == 'Online';
            return Expanded(
              child: Card(
                margin: EdgeInsets.only(right: index == state.providers.length - 1 ? 0 : 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Switch(
                        value: isOnline,
                        activeColor: Colors.black,
                        onChanged: (val) {
                          if (!val) state.killProvider(index, context);
                        },
                      ),
                      Text(p['status'], style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLedger() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("RECONCILIATION LEDGER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: state.ledger.length,
            itemBuilder: (context, index) {
              var row = state.ledger[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(row['time'], style: const TextStyle(fontSize: 12, color: Colors.grey))),
                    Expanded(child: Text(row['step'], style: const TextStyle(fontSize: 12))),
                    Expanded(child: Text(row['provider'], style: const TextStyle(fontSize: 12))),
                    Expanded(child: Text("\$${row['amount'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 2, child: Text(row['eventId'] ?? "", style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54))),
                    Expanded(flex: 2, child: Text(row['status'], style: TextStyle(fontSize: 12, color: row['status'].contains('Blocked') || row['status'].contains('Failed') ? Colors.red : Colors.green))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuditTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("AUDIT TIMELINE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: ListView.builder(
              itemCount: state.auditLog.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(state.auditLog[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showApprovalDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Budget Cap Exceeded", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("The requested cost (\$${state.currentStepCost.toStringAsFixed(2)}) exceeds the available budget limit. Do you want to manually approve this overage?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              state.resolveApproval(false);
            },
            child: const Text("Deny", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              state.resolveApproval(true);
            },
            child: const Text("Approve Override"),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Task Complete", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Cost: \$${state.spent.toStringAsFixed(2)}"),
            Text("Successful Executions: ${state.successfulExecutions}"),
            Text("Failed / No-Charge: ${state.failedOrNoChargeExecutions}"),
            Text("Duplicates Blocked: ${state.duplicatesBlocked}"),
            Text("Total Routing Attempts: ${state.totalExecutionAttempts}"),
            Text("Budget Adherence: ${state.budgetAdherenceStr}"),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}