import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nice_shot/core/themes/app_theme.dart';
import 'package:nice_shot/data/model/api/login_model.dart';
import 'package:nice_shot/logic/connected_bloc/network_bloc.dart';
import 'package:nice_shot/presentation/features/auth/pages/register_page.dart';

import 'package:nice_shot/presentation/features/main_layout/pages/home.dart';
import 'package:nice_shot/presentation/features/permissions/allow_access_page.dart';
import 'package:nice_shot/presentation/features/permissions/permissions.dart';
import 'package:nice_shot/logic/debugs/bloc_delegate.dart';
import 'package:nice_shot/presentation/router/app_router.dart';
import 'package:nice_shot/presentation/widgets/snack_bar_widget.dart';
import 'package:nice_shot/providers.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'core/functions/functions.dart';
import 'core/internet_connection.dart';
import 'core/util/enums.dart';
import 'core/util/global_variables.dart';
import 'data/network/local/cache_helper.dart';
import 'data/network/remote/dio_helper.dart';
import 'injection_container.dart' as di;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  DioHelper.init();
  ConnectionStatusSingleton.getInstance();
  FFmpegKitConfig.enableFFmpegSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
  });
  ByteData byteData = await rootBundle.load('assets/images/red_logo.png');
  String mypath=await getLogoPath();
  File(mypath).writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  await CacheHelper.init();
  await di.init();
  final directory = await path.getApplicationDocumentsDirectory();
  Hive.init(directory.path);
  await Hive.initFlutter();
  registerAdapters();
  await openBoxes();
  await AppPermissions.checkPermissions().then((value) {
    permissionsGranted = value;
  });
  Widget? page;
  final user = CacheHelper.getData(key: "user");
  if (user != null) {
    final data = LoginModel.fromJson(json.decode(user));
    setUser(user: data);
    setToken(token: currentUserData!.token.toString());
    setUserId(id: currentUserData!.user!.id.toString());
    page = const MainLayout();
  }
  if (user == null && permissionsGranted) {
    page = RegisterPage();
  }
  if (!permissionsGranted) {
    page = const AllowAccessPage();
  }
  BlocOverrides.runZoned(() {
    runApp(MyApp(page: page!));
  }, blocObserver: ApplicationBlocObserver());
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  final Widget page;

  const MyApp({Key? key, required this.page}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Camera demo',
        theme: Themes.theme,
        onGenerateRoute: Routers.generateRoute,
        home: BlocConsumer<NetworkBloc, NetworkState>(
          listener: (context, state) {
            switch (state.state!) {
              case InternetConnectionState.connected:
                ScaffoldMessenger.of(context).showSnackBar(
                  snackBarWidget(message: state.message ?? ""),
                );
                break;
              case InternetConnectionState.disconnected:
                ScaffoldMessenger.of(context).showSnackBar(
                  snackBarWidget(message: state.message ?? ""),
                );
                break;
            }
          },
          builder: (context, state) {
            return page;
          },
        ),
      ),
    );
  }
}
