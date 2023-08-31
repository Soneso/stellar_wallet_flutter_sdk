// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:logger/logger.dart';

const stellarScheme = "stellar";
const fiatScheme = "iso4217";
typedef XLM = NativeAssetId;

abstract class AssetId {
  String id;
  String scheme;

  AssetId(this.id, this.scheme);

  String get sep38 => "$scheme:$id";
}

abstract class StellarAssetId extends AssetId {
  StellarAssetId(String id) : super(id, stellarScheme);

  flutter_sdk.Asset toAsset() {
    return flutter_sdk.Asset.createFromCanonicalForm(id)!;
  }

  static StellarAssetId fromAsset(flutter_sdk.Asset asset) {
    if (asset is flutter_sdk.AssetTypeNative) {
      return NativeAssetId();
    } else if (asset is flutter_sdk.AssetTypeCreditAlphaNum) {
      return IssuedAssetId(code: asset.code, issuer: asset.issuerId);
    } else if (asset is flutter_sdk.AssetTypePoolShare) {
      Logger().w("Pool share is not supported by SDK yet");
      return IssuedAssetId(code: "", issuer: "");
      // TODO: add this when we add support for liquidity pools
    } else {
      throw UnsupportedError("Unknown asset type");
    }
  }
}

class IssuedAssetId extends StellarAssetId {
  String code;
  String issuer;

  IssuedAssetId({required this.code, required this.issuer})
      : super("$code:$issuer");

  @override
  String toString() {
    return sep38;
  }
}

class NativeAssetId extends StellarAssetId {
  NativeAssetId() : super("native");
}

class FiatAssetId extends AssetId {
  FiatAssetId(String id) : super(id, fiatScheme);

  @override
  String toString() {
    return sep38;
  }
}
