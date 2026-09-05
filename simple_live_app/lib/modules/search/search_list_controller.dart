import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SearchListController extends BasePageController {
  String keyword = "";

  /// 搜索模式，0=直播间，1=主播
  var searchMode = 0.obs;
  final verificationRequired = false.obs;
  final Site site;
  SearchListController(
    this.site,
  );

  @override
  void handleError(Object exception, {bool showPageError = false}) {
    verificationRequired.value = exception is DouyinSearchVerificationRequired;
    super.handleError(exception, showPageError: showPageError);
  }

  Future<void> verifySearch() async {
    final result = await Get.toNamed(
      RoutePath.kDouyinWebLogin,
      arguments: {'verificationKeyword': keyword},
    );
    if (result == true && !isClosed) {
      verificationRequired.value = false;
      await refreshData();
    }
  }

  @override
  Future refreshData() async {
    if (keyword.isEmpty) {
      return;
    }
    return await super.refreshData();
  }

  @override
  Future<List> getData(int page, int pageSize) async {
    if (keyword.isEmpty) {
      return [];
    }
    verificationRequired.value = false;
    if (searchMode.value == 1) {
      // 搜索主播
      var result = await site.liveSite.searchAnchors(keyword, page: page);
      return result.items;
    }
    var result = await site.liveSite.searchRooms(keyword, page: page);

    return result.items;
  }

  void clear() {
    verificationRequired.value = false;
    pageEmpty.value = false;
    list.clear();
  }
}
