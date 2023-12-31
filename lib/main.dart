import 'dart:html';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'src/data/models/annual_ward_spending_data.dart';
import 'src/data/models/map_ward_spending_data.dart';
import 'src/data/models/ward_item_location_spending_data.dart';
import 'src/data/providers/selected_data.dart';
// import 'src/data/loaders.dart';
import 'src/utils/language.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => SelectedData(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
 
  const HomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Choropleth Map Ward Spending"),
        ),
        body: _ChoroplethMap());
  }
}

class _ChoroplethMap extends StatefulWidget {
  const _ChoroplethMap({Key? key}) : super(key: key);
  @override
  __ChoroplethMapState createState() => __ChoroplethMapState();
}

class __ChoroplethMapState extends State<_ChoroplethMap> {

  late List<MapWardSpendingData> _data;
  late MapShapeSource _dataSource;
  bool _isInitialized = false;
  List<int> _years = [];
  List<String> _categories = [];
  String? _selectedCategory;
  int? _selectedYear;
  late List<MapWardSpendingData> _filteredMapData;

  Future<List<MapWardSpendingData>> _loadCSV() async {
    final _rawData = await rootBundle.loadString("assets/spending_by_category.csv");
    List<List<dynamic>> _listData = 
    const CsvToListConverter().convert(_rawData, eol: '\n', shouldParseNumbers: false,);
    List<MapWardSpendingData> spendingData = [];
    for (var i = 1; i < _listData.length; i++) {
      final item = _listData[i];
      final newData = MapWardSpendingData(
        ward: item[0],
        year: int.parse(item[2].trim()),
        category: item[1],
        percent: double.parse(item[5].trim()),
      );
      if (!_years.contains(newData.year)) {_years.add(newData.year);}
      if (!_categories.contains(newData.category)) {_categories.add(newData.category);}
      spendingData.add(newData);
    }
    return spendingData;
  }

  @override
  void initState() {

    _loadCSV().then((data) {
      setState(() {
        _data = data;
        _isInitialized = true;
        _filteredMapData = _filterMapData();
        _dataSource = createMapShapeSource();
      });
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final selectedData = Provider.of<SelectedData>(context);
    if (_selectedCategory != selectedData.selectedCategory ||
        _selectedYear != selectedData.selectedYear) {
      _selectedCategory = selectedData.selectedCategory;
      _selectedYear = selectedData.selectedYear;
      _filteredMapData = _filterMapData();
      _dataSource = createMapShapeSource();
    }
    super.didChangeDependencies();
  }

  List<MapWardSpendingData> _filterMapData() {
    if (_isInitialized) {
      return _data
          .where((element) =>
              element.category == _selectedCategory && element.year == _selectedYear)
          .toList();}
    else {return [];}
  }

  MapShapeSource createMapShapeSource() {
    if (!_isInitialized) {
      return const MapShapeSource.asset(
        'assets/Boundaries - Wards (2015-2023).geojson',
        shapeDataField: 'ward',);
    }
    else {
      return MapShapeSource.asset(
          'assets/Boundaries - Wards (2015-2023).geojson',
          shapeDataField: 'ward',
          dataCount: _filteredMapData.length,
          primaryValueMapper: (int index) =>
              _filteredMapData[index].ward,
          shapeColorValueMapper: (int index) =>
              _filteredMapData[index].percent,
          shapeColorMappers: const [
            MapColorMapper(
                from: 0,
                to: 20,
                color: Color.fromRGBO(205, 255, 255, 1),
                text: '{0},{20}'),
            MapColorMapper(
                from: 20,
                to: 40,
                color: Color.fromRGBO(157, 214, 255, 1),
                text: '40'),
            MapColorMapper(
                from: 40,
                to: 60,
                color: Color.fromRGBO(110, 168, 234, 1),
                text: '60'),
            MapColorMapper(
                from: 60,
                to: 80,
                color: Color.fromRGBO(61, 125, 188, 1),
                text: '80'),
            MapColorMapper(
                from: 80,
                to: 100,
                color: Color.fromRGBO(0, 85, 143, 1),
                text: '100'),
          ],
      );
    }
  }

  @override
  void dispose() {
    _data.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    developer.log('initialized: ${_isInitialized}');
    if (!_isInitialized) {
      return const CircularProgressIndicator();
    }
      return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            yearCategorySelector(),
            Expanded(child: wardMapCreator()),
          ],
        ),
      )
    );
  }

  SfMaps wardMapCreator() {
    return SfMaps(
            layers: [
              MapShapeLayer(
                source: _dataSource, 
                legend: MapLegend.bar(MapElement.shape),
                shapeTooltipBuilder: (BuildContext context, int index) {
                return Container(
                  width: 180,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Center(
                            child: Text(
                              'Ward: ' + _filteredMapData[index].ward,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .fontSize),
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                          color: Colors.grey,
                          height: 10,
                          thickness: 1.2,
                      ),
                      Text(
                        'Percent Spending: ' + _filteredMapData[index].percent.toStringAsFixed(1) + '%',
                        style: TextStyle(
                        color: Colors.black,
                        fontSize:
                          Theme.of(context).textTheme.bodyMedium!.fontSize),
                      ),
                    ],
                  ),
                );
              },
              tooltipSettings: const MapTooltipSettings(
                color: Colors.white,
                // strokeColor: Color.fromRGBO(252, 187, 15, 1),
                strokeWidth: 1.5),
                ), 
            ]
          );
  }
  Widget yearCategorySelector() {
    final selectedData = Provider.of<SelectedData>(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<int>(
          value: selectedData.selectedYear,
          onChanged: (int? newValue) {
            selectedData.updateSelectedYear(newValue!);
          },
          items: _years.reversed.toList()
              .map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text('$value'),
            );
          }).toList(),
        ),
        DropdownButton<String>(
          value: selectedData.selectedCategory,
          onChanged: (String? newValue) {
            selectedData.updateSelectedCategory(newValue!);
          },
          items: _categories
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text('$value'),
            );
          }).toList(),
        ),
      ],
    );
  }
}

