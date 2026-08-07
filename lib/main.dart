import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const TollgateApp());
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
  
  double totalBudget = 10.00;
  double spent = 0.00;
  double reserved = 0.00;
  
  int duplicatesBlocked = 0;
  int activeProviders = 3;
  double successRate = 100.0;
  
  // Added Reliability metric for the algorithmic scoring
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
      // Normalize values (0 to 1 scale)
      // Assuming max acceptable price is $0.20 and max latency is 200ms
      double priceScore = max(0, 1.0 - (p['price'] / 0.20)); 
      double latencyScore = max(0, 1.0 - (p['latency'] / 200.0));
      double relScore = p['reliability'];

      // Weights: 40% Price, 30% Latency, 30% Reliability
      double totalScore = (priceScore * 40) + (latencyScore * 30) + (relScore * 30);
      
      lastScores.add({
        'name': p['name'],
        'price': p['price'],
        'latency': p['latency'],
        'score': totalScore,
      });
    }

    // Sort by highest score deterministically
    lastScores.sort((a, b) => b['score'].compareTo(a['score']));
    
    // Map back to original provider object
    currentWinner = available.firstWhere((p) => p['name'] == lastScores.first['name']);
    
    // Generate algorithmic reasoning for UI
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
    double cost = forceBudgetOverage ? 12.00 : currentWinner!['price'];
    
    if (spent + reserved + cost > totalBudget) {
      policyStatus['Budget Guardrail'] = 'WARN (EXCEEDED)';
      stepStatuses[currentStepIndex] = 'Awaiting Approval';
      notifyListeners();
      return; 
    }
    
    policyStatus['Budget Guardrail'] = 'PASS';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    _executePayment(cost);
  }

  void _executePayment(double cost) async {
    reserved += cost;
    logEvent("Budget reserved: \$${cost.toStringAsFixed(2)}");
    notifyListeners();
    
    // Animate Payment Nodes
    for (int i = 0; i < 5; i++) {
      paymentNodeIndex = i;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    paymentNodeIndex = -1;

    // Settlement
    reserved -= cost;
    spent += cost;
    
    ledger.insert(0, {
      'time': DateTime.now().toIso8601String().substring(11, 19),
      'step': steps[currentStepIndex],
      'provider': currentWinner!['name'],
      'amount': cost,
      'status': 'Settled',
      'hash': '0x${Random().nextInt(999999).toRadixString(16)}'
    });
    
    stepStatuses[currentStepIndex] = 'Complete';
    logEvent("Settlement confirmed for ${steps[currentStepIndex]}");
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
      logEvent("Manual override approved. Policy forced to PASS.");
      policyStatus['Budget Guardrail'] = 'PASS (OVERRIDE)';
      notifyListeners();
      _executePayment(12.00); 
    } else {
      logEvent("Manual override denied. Step skipped.");
      stepStatuses[currentStepIndex] = 'Skipped';
      currentStepIndex++;
      _processStep();
    }
  }

  void fireDuplicatePayment(BuildContext context) {
    if (!isRunning || currentStepIndex >= steps.length) return;
    
    duplicatesBlocked++;
    ledger.insert(0, {
      'time': DateTime.now().toIso8601String().substring(11, 19),
      'step': steps[currentStepIndex],
      'provider': currentWinner?['name'] ?? 'Unknown',
      'amount': currentWinner?['price'] ?? 0.0,
      'status': 'Blocked – Duplicate',
      'hash': '0xDUP${Random().nextInt(9999).toRadixString(16)}'
    });
    
    logEvent("Duplicate request blocked (idempotency key reused).");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate request detected — blocked.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black),
    );
    notifyListeners();
  }

  void killProvider(int index, BuildContext context) {
    providers[index]['status'] = 'Offline';
    activeProviders--;
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
          'hash': '0xERR'
       });
       
       reserved = 0; 
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
      spent += entry['amount'];
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    logEvent("Replay complete — all events matched original hashes.");
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
    duplicatesBlocked = 0;
    activeProviders = 3;
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
        
        // Handle Dialog Trigger
        if (state.isRunning && state.currentStepIndex >= 0 && state.currentStepIndex < state.stepStatuses.length) {
           if (state.stepStatuses[state.currentStepIndex] == 'Awaiting Approval') {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (ModalRoute.of(context)?.isCurrent == true) {
                 _showApprovalDialog(context);
               }
             });
           }
        }

        // Handle Summary Card Trigger
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
                    // Left Column (Metrics, Task, Visuals)
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildKPIHeader(),
                            const SizedBox(height: 48),
                            _buildActiveTaskPanel(),
                            const SizedBox(height: 48),
                            _buildLivePaymentVisualizer(),
                            const Spacer(),
                            _buildProviderGrid(context),
                          ],
                        ),
                      ),
                    ),
                    // Vertical Divider
                    Container(width: 1, color: const Color(0xFFEEEEEE)),
                    // Right Column (Decision Engine, Treasury, Ledger, Audit)
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTreasuryMeter(),
                            const SizedBox(height: 24),
                            // Replaced old route panel with the new Decision Engine Panel
                            if (state.currentWinner != null || state.isRunning) _buildDecisionEnginePanel(),
                            const SizedBox(height: 24),
                            Expanded(child: _buildLedger()),
                            const SizedBox(height: 16),
                            Expanded(child: _buildAuditTimeline()),
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
        _kpiTile("Success Rate", "${state.successRate}%"),
        _kpiTile("Budget Adherence", "100%"),
        _kpiTile("Active Providers", "${state.activeProviders}/3"),
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
                        decoration: BoxDecoration(
                          color: nodeColor,
                          shape: BoxShape.circle,
                        ),
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

  // --- NEW DECISION ENGINE PANEL ---
  Widget _buildDecisionEnginePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("POLICY EVALUATION & ROUTING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
            const SizedBox(height: 16),
            
            // 1. Policy Gates
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
              // 2. Algorithmic Routing Scores
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
                        Text("Score: ${scoreCard['score'].toStringAsFixed(1)}", style: TextStyle(fontWeight: isWinner ? FontWeight.bold : FontWeight.normal, color: isWinner ? Colors.black : Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 12),
              
              // 3. Decision Explanation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Selected: ${state.currentWinner!['name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 4),
                    Text("Reason: ${state.currentWinner!['reason']}", style: TextStyle(fontSize: 12, color: Colors.green[800])),
                  ],
                ),
              )
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
            Text("Available: \$${(state.totalBudget - state.spent - state.reserved).toStringAsFixed(2)}", style: const TextStyle(fontSize: 12)),
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
         const Text("PROTOCOL VISUALIZER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(state.providers.length, (index) {
        var p = state.providers[index];
        bool isOnline = p['status'] == 'Online';
        return Card(
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
        );
      }),
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
        content: const Text("The requested reservation exceeds the available budget. Do you want to manually approve this overage?"),
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
            Text("Duplicates Blocked: ${state.duplicatesBlocked}"),
            const Text("Budget Adherence: 100%"),
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