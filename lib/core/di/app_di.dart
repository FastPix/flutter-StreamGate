import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../../features/upload/data/fastpix_upload_engine.dart';
import '../../features/record/presentation/record_viewmodel.dart';
import '../../features/upload/presentation/upload_viewmodel.dart';

class AppDI {
  // ----------------------------
  // 🌐 SERVICES (SINGLETONS)
  // ----------------------------

  static final FastPixUploadService fastPixEngine = FastPixUploadService(
    tokenId: FastPixConstants.tokenId,
    secretKey: FastPixConstants.secretKey,
  );

  // ----------------------------
  // 📦 PROVIDERS (VIEWMODELS)
  // ----------------------------

  static List<ChangeNotifierProvider> providers() {
    return [
      ChangeNotifierProvider<RecordViewModel>(
        create: (_) => RecordViewModel(),
      ),
      ChangeNotifierProvider<UploadViewModel>(
        create: (_) => UploadViewModel(fastPixEngine),
      ),
    ];
  }
}
