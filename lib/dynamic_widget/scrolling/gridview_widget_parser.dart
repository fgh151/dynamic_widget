import 'dart:convert';
import 'dart:io';

import 'package:dynamic_widget/dynamic_widget.dart';
import 'package:dynamic_widget/dynamic_widget/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';

class GridViewWidgetParser extends WidgetParser {
  @override
  bool forWidget(String widgetName) {
    return "GridView" == widgetName;
  }

  @override
  Widget parse(Map<String, dynamic> map, ClickListener listener) {
    var scrollDirection = Axis.vertical;
    if (map.containsKey("scrollDirection") && "horizontal" == map[""]) {
      scrollDirection = Axis.horizontal;
    }
    int crossAxisCount = map['crossAxisCount'];
    bool reverse = map.containsKey("reverse") ? map['reverse'] : false;
    bool shrinkWrap = map.containsKey("shrinkWrap") ? map["shrinkWrap"] : false;
    double cacheExtent =
        map.containsKey("cacheExtent") ? map["cacheExtent"] : 0.0;
    EdgeInsetsGeometry padding = map.containsKey('padding')
        ? parseEdgeInsetsGeometry(map['padding'])
        : null;
    double mainAxisSpacing =
        map.containsKey('mainAxisSpacing') ? map['mainAxisSpacing'] : 0.0;
    double crossAxisSpacing =
        map.containsKey('crossAxisSpacing') ? map['crossAxisSpacing'] : 0.0;
    double childAspectRatio =
        map.containsKey('childAspectRatio') ? map['childAspectRatio'] : 1.0;
    var children = DynamicWidgetBuilder.buildWidgets(map['children'], listener);

    var pageSize = map.containsKey("pageSize") ? map["pageSize"] : 10;
    var loadMoreUrl =
        map.containsKey("loadMoreUrl") ? map["loadMoreUrl"] : null;
    var isDemo = map.containsKey("isDemo") ? map["isDemo"] : false;

    GridViewParams params = GridViewParams(
        crossAxisCount,
        scrollDirection,
        reverse,
        shrinkWrap,
        cacheExtent,
        padding,
        mainAxisSpacing,
        crossAxisSpacing,
        childAspectRatio,
        children,
        pageSize,
        loadMoreUrl,
        isDemo);
    return GridViewWidget(params);
  }
}

class GridViewWidget extends StatefulWidget {
  GridViewParams _params;

  GridViewWidget(this._params);

  @override
  _GridViewWidgetState createState() => _GridViewWidgetState(_params);
}

class _GridViewWidgetState extends State<GridViewWidget> {
  GridViewParams _params;
  List<Widget> _items = [];

  ScrollController _scrollController = new ScrollController();
  bool isPerformingRequest = false;

  //If there are no more items, it should not try to load more data while scroll
  //to bottom.
  bool loadCompleted = false;

  _GridViewWidgetState(this._params) {
    if (_params.children != null) {
      _items.addAll(_params.children);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_params.loadMoreUrl == null || _params.loadMoreUrl.isEmpty) {
      loadCompleted = true;
      return;
    }
    _scrollController.addListener(() {
      if (!loadCompleted &&
          _scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent) {
        _getMoreData();
      }
    });
  }

  _getMoreData() async {
    if (!isPerformingRequest) {
      setState(() => isPerformingRequest = true);
      var jsonString = _params.isDemo ? await fakeRequest() : await doRequest();
      var buildWidgets =
          DynamicWidgetBuilder.buildWidgets(jsonDecode(jsonString), null);
      setState(() {
        if (buildWidgets.isEmpty) {
          loadCompleted = true;
        }
        _items.addAll(buildWidgets);
        isPerformingRequest = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildProgressIndicator() {
    return new SliverToBoxAdapter(
      child: Visibility(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: new Center(
            child: new Opacity(
              opacity: isPerformingRequest ? 1.0 : 0.0,
              child: new CircularProgressIndicator(),
            ),
          ),
        ),
        visible: !loadCompleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var footer = _buildProgressIndicator();
    var sliverGrid = SliverPadding(
      padding: _params.padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _params.crossAxisCount,
            mainAxisSpacing: _params.mainAxisSpacing,
            crossAxisSpacing: _params.crossAxisSpacing,
            childAspectRatio: _params.childAspectRatio),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return _items[index];
          },
          childCount: _items.length,
        ),
      ),
    );

    return new CustomScrollView(
      slivers: <Widget>[sliverGrid, footer],
      controller: _scrollController,
      scrollDirection: _params.scrollDirection,
      reverse: _params.reverse,
      shrinkWrap: _params.shrinkWrap,
      cacheExtent: _params.cacheExtent,
    );
  }

  fakeRequest() async {
// 如果对Future不熟悉，可以参考 https://juejin.im/post/5b2c67a351882574a756f2eb
    return Future.delayed(Duration(seconds: 2), () {
      return """
[
    {
      "type": "AssetImage",
      "name": "assets/vip.png"
    },
    {
      "type": "AssetImage",
      "name": "assets/vip.png"
    },
    {
      "type": "AssetImage",
      "name": "assets/vip.png"
    },
    {
      "type": "AssetImage",
      "name": "assets/vip.png"
    }
]          
      """;
    });
  }

  doRequest() async {
    var httpClient = new HttpClient();
    try {
      var request = await httpClient.getUrl(Uri.parse(getLoadMoreUrl(
          _params.loadMoreUrl, _items.length, _params.pageSize)));
      var response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        var json = await response.transform(utf8.decoder).join();
        return json;
      }
    } catch (exception) {
      print(exception);
    }
    return "";
  }
}

class GridViewParams {
  int crossAxisCount;
  Axis scrollDirection;
  bool reverse;
  bool shrinkWrap;
  double cacheExtent;
  EdgeInsetsGeometry padding;
  double mainAxisSpacing;
  double crossAxisSpacing;
  double childAspectRatio;
  List<Widget> children;

  int pageSize;
  String loadMoreUrl;

  //use for demo, if true, it will do the fake request.
  bool isDemo;

  GridViewParams(
      this.crossAxisCount,
      this.scrollDirection,
      this.reverse,
      this.shrinkWrap,
      this.cacheExtent,
      this.padding,
      this.mainAxisSpacing,
      this.crossAxisSpacing,
      this.childAspectRatio,
      this.children,
      this.pageSize,
      this.loadMoreUrl,
      this.isDemo);
}