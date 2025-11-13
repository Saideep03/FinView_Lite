import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FinViewLiteApp());
}

class FinViewLiteApp extends StatelessWidget {
  const FinViewLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinView Lite',
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: _isLoggedIn(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data! ? PortfolioScreen() : LoginScreen();
        },
      ),
    );
  }

  static Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_in') ?? false;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  Future<void> _login() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = "Please enter a name.");
      return;
    }
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', _controller.text.trim());
    await prefs.setBool('logged_in', true);
    setState(() => _loading = false);
    // ignore: use_build_context_synchronously
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PortfolioScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF141e30),
      body: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 28),
          padding: EdgeInsets.symmetric(vertical: 38, horizontal: 26),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade800.withOpacity(0.93),
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.24),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FinView Lite',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 31,
                  color: Colors.white,
                  letterSpacing: 1.8,
                ),
              ),
              SizedBox(height: 17),
              Text(
                'Login to your portfolio',
                style: GoogleFonts.poppins(
                  color: Colors.tealAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 26),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelStyle: GoogleFonts.poppins(color: Colors.tealAccent),
                ),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
                enabled: !_loading,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade700,
                    foregroundColor: Colors.blueGrey.shade900,
                    padding: EdgeInsets.symmetric(vertical: 11),
                    textStyle: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(strokeWidth: 2.7),
                        )
                      : Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with TickerProviderStateMixin {
  bool isDarkMode = false;
  Map<String, dynamic>? portfolioData;
  bool showPercentage = true;
  String sortCriterion = 'value';
  late final AnimationController listAnimationController;
  late final AnimationController pieChartAnimationController;
  late final AnimationController themeAnimationController;
  final GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();
  List<Map> currentHoldings = [];
  int? selectedPieIndex;
  String? user;

  @override
  void initState() {
    super.initState();
    loadPortfolio();
    listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    pieChartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    themeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _setUser();
  }

  Future<void> _setUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    user = prefs.getString('user') ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    listAnimationController.dispose();
    pieChartAnimationController.dispose();
    themeAnimationController.dispose();
    super.dispose();
  }

  Future<void> loadPortfolio({bool simulateRefresh = false}) async {
    String jsonString = await rootBundle.loadString('assets/portfolio.json');
    final data = json.decode(jsonString);

    if (simulateRefresh) {
      // Simulate price update: randomize current_price by ±1-3%
      final rnd = Random();
      for (var h in data['holdings']) {
        var change = (rnd.nextDouble() * 0.03) * (rnd.nextBool() ? 1 : -1);
        h['current_price'] = (h['current_price'] * (1 + change))
            .toStringAsFixed(2);
      }
      data['portfolio_value'] = data['holdings'].fold(
        0.0,
        (sum, h) =>
            sum + (double.parse(h['current_price'].toString()) * h['units']),
      );
      data['total_gain'] = data['holdings'].fold(
        0.0,
        (sum, h) =>
            sum +
            ((double.parse(h['current_price'].toString()) - h['avg_cost']) *
                h['units']),
      );
    }

    setState(() {
      portfolioData = data;
      currentHoldings = sortedHoldings();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int i = 0; i < currentHoldings.length; i++) {
        listKey.currentState?.insertItem(
          i,
          duration: Duration(milliseconds: 200 + i * 70),
        );
      }
      listAnimationController.forward();
      pieChartAnimationController.forward();
    });
  }

  double calculateGain(Map holding) {
    double cost =
        (double.parse(holding['avg_cost'].toString())) *
        (holding['units'] as num).toDouble();
    double currentValue =
        (double.parse(holding['current_price'].toString())) *
        (holding['units'] as num).toDouble();
    return currentValue - cost;
  }

  double calculateValue(Map holding) {
    return (double.parse(holding['current_price'].toString())) *
        (holding['units'] as num).toDouble();
  }

  List<Map> sortedHoldings() {
    List<Map> holdings = List<Map>.from(portfolioData?['holdings'] ?? []);
    holdings.sort((a, b) {
      switch (sortCriterion) {
        case 'gain':
          return calculateGain(b).compareTo(calculateGain(a));
        case 'name':
          return a['name'].compareTo(b['name']);
        case 'value':
        default:
          return calculateValue(b).compareTo(calculateValue(a));
      }
    });
    return holdings;
  }

  Widget buildDarkModeToggle() {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () async {
          themeAnimationController.forward(from: 0.0);
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return RotationTransition(turns: animation, child: child);
          },
          child: Icon(
            isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            key: ValueKey<bool>(isDarkMode),
            color: isDarkMode
                ? const Color.fromARGB(255, 0, 0, 0)
                : Colors.orangeAccent,
            size: 31,
          ),
        ),
      ),
    );
  }

  Widget buildReturnsToggle() {
    return Row(
      children: [
        Text(
          'Show Returns:',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: isDarkMode
                ? Colors.tealAccent
                : const Color.fromARGB(255, 144, 161, 255),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            showPercentage ? 'Percentage' : 'Amount',
            key: ValueKey<bool>(showPercentage),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDarkMode
                  ? Colors.tealAccent
                  : const Color.fromARGB(255, 144, 160, 255),
            ),
          ),
        ),
        Switch(
          value: showPercentage,
          onChanged: (val) {
            setState(() {
              showPercentage = val;
            });
          },
        ),
      ],
    );
  }

  Widget buildSortingDropdown() {
    final Map<String, IconData> icons = {
      'value': Icons.pie_chart_rounded,
      'gain': Icons.trending_up_rounded,
      'name': Icons.sort_by_alpha_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButton<String>(
        value: sortCriterion,
        dropdownColor: isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.arrow_drop_down,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        onChanged: (val) async {
          final itemsCount = currentHoldings.length;
          setState(() {
            sortCriterion = val ?? 'value';
            currentHoldings = sortedHoldings();
          });
          for (int i = itemsCount - 1; i >= 0; i--) {
            listKey.currentState?.removeItem(
              i,
              (context, animation) => SizeTransition(
                sizeFactor: animation,
                child: const SizedBox.shrink(),
              ),
              duration: const Duration(milliseconds: 140),
            );
          }
          await Future.delayed(const Duration(milliseconds: 260));
          for (int i = 0; i < currentHoldings.length; i++) {
            listKey.currentState?.insertItem(
              i,
              duration: Duration(milliseconds: 180 + i * 45),
            );
          }
        },
        selectedItemBuilder: (BuildContext context) {
          return icons.entries.map((entry) {
            return Row(
              children: [
                Icon(
                  entry.value,
                  color: isDarkMode ? Colors.white : Colors.indigo,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  'By ${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            );
          }).toList();
        },
        items: icons.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(
                      entry.value,
                      color: isDarkMode ? Colors.white : Colors.indigo,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'By ${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget buildHoldingItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    if (index < 0 || index >= currentHoldings.length) {
      return const SizedBox.shrink();
    }
    final stock = currentHoldings[index];
    final gain = calculateGain(stock);
    final originalCost =
        (double.parse(stock['avg_cost'].toString())) *
        (stock['units'] as num).toDouble();
    final gainToShow = showPercentage
        ? '${(gain / originalCost * 100).toStringAsFixed(2)}%'
        : '₹${gain.toStringAsFixed(2)}';

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuint)),
      child: FadeTransition(
        opacity: animation,
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          color: isDarkMode
              ? Colors.blueGrey.shade800.withOpacity(0.90)
              : Colors.white.withOpacity(0.96),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ListTile(
              title: Text(
                stock['name'],
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDarkMode ? Colors.tealAccent : Color(0xFF0D47A1),
                ),
              ),
              subtitle: Text(
                'Units: ${stock['units']}  •  Cost: ₹${double.parse(stock['avg_cost'].toString())}  •  Current: ₹${double.parse(stock['current_price'].toString())}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white70 : Colors.indigo[900],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Gain/Loss',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 550),
                    style: TextStyle(
                      color: gain >= 0
                          ? (isDarkMode ? Colors.tealAccent : Colors.green)
                          : (isDarkMode ? Colors.redAccent : Colors.red),
                      fontWeight: FontWeight.w700,
                      fontFamily: GoogleFonts.montserrat().fontFamily,
                      fontSize: 16,
                    ),
                    child: Text(gainToShow),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHoldingsList() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.32,
      ),
      child: ListView.builder(
        itemCount: currentHoldings.length,
        itemBuilder: (context, index) =>
            buildHoldingItem(context, index, AlwaysStoppedAnimation(1)),
        shrinkWrap: true,
      ),
    );
  }

  Widget buildHoldingsLegend(double portfolioValue) {
    final List<Color> colorPalette = isDarkMode
        ? [
            Colors.blueAccent,
            Colors.deepPurpleAccent,
            Colors.redAccent,
            Colors.tealAccent,
            Colors.amberAccent,
            Colors.lightGreenAccent,
            Colors.pinkAccent,
            Colors.cyanAccent,
          ]
        : [
            Colors.indigoAccent,
            Colors.deepPurple,
            Colors.pinkAccent,
            Colors.cyan,
            Colors.amber,
            Colors.lightBlue,
            Colors.lime,
            Colors.redAccent,
          ];

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blueGrey.shade800.withOpacity(0.82)
            : Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.indigoAccent.withOpacity(0.08)
                : Colors.indigo.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 17,
          runSpacing: 7,
          children: List.generate(currentHoldings.length, (index) {
            final e = currentHoldings[index];
            final color = colorPalette[index % colorPalette.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  "${e['symbol']}",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDarkMode ? Colors.tealAccent : Colors.indigo,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget buildProfessionalPieChart(double portfolioValue) {
    final List<Color> colorPalette = isDarkMode
        ? [
            Colors.blueAccent,
            Colors.deepPurpleAccent,
            Colors.redAccent,
            Colors.tealAccent,
            Colors.amberAccent,
            Colors.lightGreenAccent,
            Colors.pinkAccent,
            Colors.cyanAccent,
          ]
        : [
            Colors.indigoAccent,
            Colors.deepPurple,
            Colors.pinkAccent,
            Colors.cyan,
            Colors.amber,
            Colors.lightBlue,
            Colors.lime,
            Colors.redAccent,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 290,
          width: 290,
          child: Center(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3.5,
                centerSpaceRadius: 54,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (response != null && response.touchedSection != null) {
                      setState(() {
                        selectedPieIndex =
                            response.touchedSection!.touchedSectionIndex;
                      });
                    } else {
                      setState(() => selectedPieIndex = null);
                    }
                  },
                ),
                sections: currentHoldings.asMap().entries.map((entry) {
                  final e = entry.value;
                  final index = entry.key;
                  final value = calculateValue(e);
                  final percentage = value / portfolioValue * 100;
                  final isSelected = selectedPieIndex == index;

                  return PieChartSectionData(
                    color: colorPalette[index % colorPalette.length],
                    value: value,
                    title:
                        "${percentage < 0.1 ? '<0.1' : percentage.toStringAsFixed(1)}%",
                    titlePositionPercentageOffset: 0.5,
                    titleStyle: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 7,
                          color: Colors.black.withOpacity(0.55),
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    radius: isSelected ? 75 : 65,
                    badgeWidget: isSelected
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.black87 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      colorPalette[index % colorPalette.length]
                                          .withOpacity(0.33),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              "${e['symbol']} ${percentage.toStringAsFixed(1)}%",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.tealAccent
                                    : colorPalette[index % colorPalette.length],
                                fontSize: 15,
                              ),
                            ),
                          )
                        : null,
                    badgePositionPercentageOffset: 1.19,
                    borderSide: isSelected
                        ? BorderSide(color: Colors.amberAccent, width: 3)
                        : BorderSide.none,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        buildHoldingsLegend(portfolioValue),
        if (selectedPieIndex != null &&
            selectedPieIndex! >= 0 &&
            selectedPieIndex! < currentHoldings.length)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.blueGrey.shade900
                      : Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.indigoAccent.withOpacity(0.07)
                          : Colors.indigo.withOpacity(0.07),
                      blurRadius: 17,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      color: Colors.amberAccent,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "${currentHoldings[selectedPieIndex!]['name']} (${currentHoldings[selectedPieIndex!]['symbol']}): "
                      "${calculateValue(currentHoldings[selectedPieIndex!]).toStringAsFixed(2)} INR"
                      " • ${((calculateValue(currentHoldings[selectedPieIndex!]) / portfolioValue) * 100).toStringAsFixed(1)}%",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildFinanceBgFullScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Color(0xFF141e30), Color(0xFF243b55)]
              : [
                  Color.fromARGB(255, 44, 115, 208),
                  Color.fromARGB(255, 255, 255, 255),
                  Color(0xFFFFEFBA),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: DecorationImage(
          image: AssetImage('assets/bg_finance.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            isDarkMode
                ? Colors.black.withOpacity(0.13)
                : const Color.fromARGB(255, 255, 254, 254).withOpacity(0.15),
            BlendMode.srcOver,
          ),
        ),
      ),
    );
  }

  Widget buildPortfolioSummary(
    double portfolioValue,
    double totalGain,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [Color(0xFF0F2027), Color(0xFF2C5364)]
                : [Color(0xFFF8FFAE), Color(0xFF43C6AC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.tealAccent.withOpacity(0.10)
                  : Colors.blue.withOpacity(0.08),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: isDark ? Colors.amberAccent : Colors.indigo,
                          size: 29,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Portfolio Value",
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              color: isDark
                                  ? const Color.fromARGB(255, 138, 147, 250)
                                  : Colors.indigo.shade900,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      "₹${portfolioValue.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : Colors.indigo.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.3,
                height: 45,
                color: isDark ? Colors.white24 : Colors.indigo.shade100,
                margin: EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          totalGain >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: totalGain >= 0
                              ? (isDark ? Colors.greenAccent : Colors.green)
                              : (isDark ? Colors.redAccent : Colors.red),
                          size: 29,
                        ),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            "Total Gain/Loss",
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              color: isDark
                                  ? Colors.tealAccent
                                  : totalGain >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      "₹${totalGain.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        color: totalGain >= 0
                            ? (isDark ? Colors.greenAccent : Colors.green[900])
                            : (isDark ? Colors.redAccent : Colors.red[800]),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: Color.fromARGB(255, 64, 123, 211),
      colorScheme: ColorScheme.light(
        primary: Color.fromARGB(255, 71, 144, 255),
        secondary: Color.fromARGB(255, 58, 182, 240),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 49, 87, 145),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
    );

    final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: Color(0xFF222C35),
      colorScheme: ColorScheme.dark(
        primary: Color.fromARGB(255, 74, 158, 242),
        secondary: Color(0xFF00B8D4),
      ),
      scaffoldBackgroundColor: const Color.fromARGB(0, 255, 133, 133),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 0, 40, 74),
        foregroundColor: Color.fromARGB(255, 255, 255, 255),
        elevation: 5,
      ),
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    );

    if (portfolioData == null) {
      return MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('FinView Lite'),
            centerTitle: true,
            actions: [buildDarkModeToggle()],
          ),
          body: Stack(
            children: [
              buildFinanceBgFullScreen(),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    final portfolioValue = (portfolioData!['portfolio_value'] as num)
        .toDouble();
    final totalGain = (portfolioData!['total_gain'] as num).toDouble();

    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SafeArea(
        child: AnimatedBuilder(
          animation: themeAnimationController,
          builder: (context, _) {
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: [
                        Color.fromARGB(255, 255, 255, 255),
                        Color.fromARGB(255, 255, 255, 255),
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    'FinView Lite',
                    style: GoogleFonts.montserrat(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: Colors.redAccent),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                  buildDarkModeToggle(),
                ],
              ),
              body: Stack(
                children: [
                  buildFinanceBgFullScreen(),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: RefreshIndicator(
                      onRefresh: () => loadPortfolio(simulateRefresh: true),
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(top: 60),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Hello,              $user',
                              style: GoogleFonts.montserrat(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                foreground: Paint()
                                  ..shader =
                                      LinearGradient(
                                        colors: isDarkMode
                                            ? [Color(0xFF29B6F6), Colors.white]
                                            : [
                                                Color.fromARGB(
                                                  255,
                                                  0,
                                                  174,
                                                  255,
                                                ),
                                                Color.fromARGB(
                                                  255,
                                                  255,
                                                  255,
                                                  255,
                                                ),
                                              ],
                                      ).createShader(
                                        const Rect.fromLTWH(50, 50, 200, 30),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            buildPortfolioSummary(
                              portfolioValue,
                              totalGain,
                              isDarkMode,
                            ),
                            const SizedBox(height: 8),
                            Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color.fromARGB(
                                          255,
                                          38,
                                          50,
                                          56,
                                        ).withOpacity(0.85)
                                      : const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ).withOpacity(0.93),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 8,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Holdings',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            foreground: Paint()
                                              ..shader =
                                                  LinearGradient(
                                                    colors: isDarkMode
                                                        ? [
                                                            Color(0xFF29B6F6),
                                                            Colors.white,
                                                          ]
                                                        : [
                                                            Color.fromARGB(
                                                              255,
                                                              28,
                                                              37,
                                                              141,
                                                            ),
                                                            Color.fromARGB(
                                                              255,
                                                              28,
                                                              37,
                                                              141,
                                                            ),
                                                          ],
                                                  ).createShader(
                                                    const Rect.fromLTWH(
                                                      0,
                                                      0,
                                                      140,
                                                      30,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        buildSortingDropdown(),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    buildHoldingsList(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            buildReturnsToggle(),
                            const SizedBox(height: 16),
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.74, end: 1.0)
                                  .animate(
                                    CurvedAnimation(
                                      parent: pieChartAnimationController,
                                      curve: Curves.easeOutBack,
                                    ),
                                  ),
                              child: GestureDetector(
                                onTapDown: (details) {
                                  setState(() => selectedPieIndex = null);
                                },
                                child: buildProfessionalPieChart(
                                  portfolioValue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
