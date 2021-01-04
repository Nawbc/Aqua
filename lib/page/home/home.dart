import 'dart:async';
import 'package:file_editor/editor_theme.dart';
import 'package:file_editor/file_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lan_file_more/common/socket/socket.dart';
import 'package:lan_file_more/common/widget/show_modal_entity.dart';
import 'package:lan_file_more/common/widget/show_modal.dart';
import 'package:lan_file_more/constant/constant.dart';
import 'package:lan_file_more/constant/constant_var.dart';
import 'package:lan_file_more/external/bot_toast/src/toast.dart';
import 'package:lan_file_more/model/file_model.dart';
import 'package:lan_file_more/page/file_manager/file_manager.dart';
import 'package:lan_file_more/page/file_manager/file_utils.dart';
import 'package:lan_file_more/page/lan/lan.dart';
import 'package:lan_file_more/page/not_support/not_support.dart';
import 'package:lan_file_more/page/photo_viewer/photo_viewer.dart';
import 'package:lan_file_more/page/setting/setting.dart';
import 'package:lan_file_more/model/common_model.dart';
import 'package:lan_file_more/model/theme_model.dart';
import 'package:lan_file_more/page/video/meida_info.dart';
import 'package:lan_file_more/page/video/video.dart';
import 'package:lan_file_more/utils/error.dart';
import 'package:lan_file_more/utils/mix_utils.dart';
import 'package:lan_file_more/utils/req.dart';
import 'package:lan_file_more/utils/theme.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:storage_mount_listener/storage_mount_listener.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as pathLib;

class HomePage extends StatefulWidget {
  HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MethodChannel _platform = const MethodChannel(SHARED_CHANNEL);
  ThemeModel _themeModel;
  CupertinoTabController _tabController;
  CommonModel _commonModel;
  bool _mutex;

  StreamSubscription _storageSubscription;
  Map _appIncoming;

  void showText(String content) {
    BotToast.showText(text: content);
  }

  Future<void> _preloadWebData() async {
    String baseUrl = _commonModel?.baseUrl;
    if (baseUrl != null) {
      await req().get(baseUrl + '/assets/index.json').then((receive) async {
        dynamic data = receive.data;
        if (data['baseUrl'] != null &&
            data['baseUrl'] != baseUrl &&
            MixUtils.isHttpUrl(data['baseUrl'])) {
          await _commonModel.setBaseUrl(data['baseUrl']);
        }
        await _commonModel.setGobalWebData(receive.data);
      }).catchError((err) {
        BotToast.showText(text: '首次请求出现错误, 导出日志与开发者联系');
        recordError(text: '', methodName: '_preloadWebData');
      });
    } else {
      BotToast.showText(text: '地址错误, 导出日志与开发者联系');
      recordError(text: 'baseUrl为null', methodName: '_preloadWebData');
    }
  }

  Future<void> _forceReadTutorialModal() async {
    await showForceScopeModal(
      context,
      _themeModel,
      title: '请仔细阅读教程',
      tip: '该界面无返返回, 需前往教程后, 方可消失',
      defaultOkText: '前往教程',
      onOk: () async {
        if (await canLaunch(TUTORIAL_URL)) {
          await launch(TUTORIAL_URL);
        }
      },
      defaultCancelText: '前往bilibili',
      onCancel: () async {
        if (await canLaunch(TUTORIAL_URL)) {
          await launch(TUTORIAL_URL);
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
    _mutex = true;

    _storageSubscription = StorageMountListener.channel
        .receiveBroadcastStream()
        .listen((event) {});

    QuickActions quickActions = QuickActions();

    quickActions.setShortcutItems(
      <ShortcutItem>[
        const ShortcutItem(
          type: 'static-server',
          localizedTitle: '静态服务',
          icon: 'content',
        ),
        const ShortcutItem(
          type: 'vscode-server',
          localizedTitle: 'Vscode Server',
          icon: 'vscode',
        ),
      ],
    );

    quickActions.initialize((String shortcutType) {
      switch (shortcutType) {
        case 'static-server':
          _tabController.index = 1;
          break;
        case 'vscode-server':
          _tabController.index = 1;
          break;
        default:
      }
    });
  }

  // Future<void> _requestMicphonePermissionModal() async {
  //   await showTipTextModal(
  //     context,
  //     _themeModel,
  //     title: '权限请求',
  //     tip: '由于软件支持录屏功能, 需要麦克风的权限',
  //     defaultOkText: '获取权限',
  //     onOk: () async {
  //       await PermissionHandler()
  //           .requestPermissions(<PermissionGroup>[PermissionGroup.microphone]);
  //     },
  //     onCancel: () {
  //       MixUtils.safePop(context);
  //     },
  //   );
  // }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _themeModel = Provider.of<ThemeModel>(context);
    _commonModel = Provider.of<CommonModel>(context);

    if (_mutex) {
      _mutex = false;

      StorageMountListener.channel.receiveBroadcastStream().listen((event) {});

      // PermissionStatus status = await PermissionHandler()
      //     .checkPermissionStatus(PermissionGroup.microphone);
      //   if (PermissionStatus.granted != status) {
      //     // 提示用户 需要麦克风 权限 否则 无法进入
      //     await _requestMicphonePermissionModal(context);
      //   }
      //   // 强制阅读使用教程 跳转后取消

      await _preloadWebData().catchError((err) {});

      _appIncoming = await _platform.invokeMethod('getIncomingFile');

      setState(() {});

      if (_commonModel.isAppNotInit) {
        await _forceReadTutorialModal();
        _commonModel.setAppInit(false);
      }

      Timer(Duration(seconds: 8), () async {
        await showUpdateModal(context, _themeModel, _commonModel.gWebData);
      });

      if (_commonModel.enableConnect &&
          (_appIncoming == null || _appIncoming['appMode'] == 'normal')) {
        Timer(Duration(seconds: 1), () async {
          await SocketConnecter.searchDevicesAndConnect(
            context,
            themeModel: _themeModel,
            commonModel: _commonModel,
            onNotExpected: (String msg) {
              showText(msg);
            },
          ).catchError((err) {});
        });
      }
    }
  }

  Widget switchEntryPage(Map _incomingFile, {LanFileMoreTheme themeData}) {
    if (_incomingFile != null && _incomingFile['appMode'] == 'incoming') {
      String ext = pathLib.extension(_incomingFile['path']).toLowerCase();
      String filename = pathLib.basename(_incomingFile['path']);
      String path = _incomingFile['path'];

      return LanFileUtils.matchEntryByMimeType(
        _incomingFile['type'],
        caseImage: () {
          return PhotoViewer(
            imageRes: [path],
            index: 0,
          );
        },
        caseText: () {
          return FileEditorPage(
            path: path,
            language: ext.replaceFirst(RegExp(r'.'), ''),
            bottomNavColor: _themeModel.themeData?.bottomNavColor,
            dialogBgColor: _themeModel.themeData?.dialogBgColor,
            backgroundColor: _themeModel.themeData?.scaffoldBackgroundColor,
            fontColor: _themeModel.themeData?.itemFontColor,
            selectItemColor: _themeModel.themeData?.itemColor,
            popMenuColor: _themeModel.themeData?.menuItemColor,
            highlightTheme: setEditorTheme(
              _themeModel.isDark,
              TextStyle(
                color: _themeModel.themeData?.itemFontColor,
                backgroundColor: _themeModel.themeData?.scaffoldBackgroundColor,
              ),
            ),
          );
        },
        // caseAudio: () {},
        caseVideo: () {
          return VideoPage(
            info: MediaInfo(
              name: filename,
              path: path,
            ),
          );
        },
        caseBinary: () {
          return NotSupportPage(
            content: '不支持打开二进制文件',
            path: path,
          );
        },
        caseDefault: () {
          return NotSupportPage(
            path: path,
          );
        },
      );
    } else {
      return CupertinoTabScaffold(
        controller: _tabController,
        tabBar: CupertinoTabBar(
          backgroundColor: themeData.bottomNavColor,
          border: Border(),
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              label: '文件',
              icon: Icon(OMIcons.folder),
            ),
            BottomNavigationBarItem(
              label: '更多',
              icon: Icon(Icons.devices),
            ),
            BottomNavigationBarItem(
              label: '设置',
              icon: Icon(OMIcons.settings),
            )
          ],
        ),
        tabBuilder: (BuildContext context, int index) {
          switch (index) {
            case 0:
              return CupertinoTabView(
                builder: (context) => FileManagerPage(
                  mode: FileManagerMode.surf,
                ),
              );
            case 1:
              return CupertinoTabView(
                builder: (context) => LanPage(),
              );
            case 2:
              return CupertinoTabView(
                builder: (context) => ChangeNotifierProvider(
                  create: (_) => FileModel(),
                  child: SettingPage(
                    gTabController: _tabController,
                  ),
                ),
              );
            default:
              assert(false, 'Unexpected tab');
              return null;
          }
        },
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    _storageSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    LanFileMoreTheme themeData = _themeModel?.themeData;
    return themeData == null
        ? Container(color: themeData.scaffoldBackgroundColor)
        : switchEntryPage(
            _appIncoming,
            themeData: themeData,
          );
  }
}
