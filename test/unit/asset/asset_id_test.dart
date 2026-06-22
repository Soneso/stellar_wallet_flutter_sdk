// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  // A valid Stellar account id (G... address) used as an asset issuer.
  const issuer = "GDUKMGUGDZQK6YHYA5Z6AY2G4XDSZPSZ3SW5UN3ARVMO6QSRDWP5YLEX";
  // A second, distinct valid Stellar account id.
  const otherIssuer =
      "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN";

  group('AssetId Tests', () {
    test('sep38 combines scheme and id', () {
      final asset = IssuedAssetId(code: "USDC", issuer: issuer);
      expect(asset.sep38, "stellar:USDC:$issuer");
    });

    test('id and scheme fields are exposed from the base class', () {
      final native = NativeAssetId();
      expect(native.id, "native");
      expect(native.scheme, stellarScheme);

      final fiat = FiatAssetId("USD");
      expect(fiat.id, "USD");
      expect(fiat.scheme, fiatScheme);
    });

    test('scheme constants have the expected SEP-38 values', () {
      expect(stellarScheme, "stellar");
      expect(fiatScheme, "iso4217");
    });
  });

  group('StellarAssetId Tests', () {
    test('XLM typedef refers to NativeAssetId', () {
      final XLM xlm = XLM();
      expect(xlm, isA<NativeAssetId>());
      expect(xlm, isA<StellarAssetId>());
      expect(xlm.sep38, "stellar:native");
    });

    test('fromAsset on the native asset yields a NativeAssetId', () {
      final asset = flutter_sdk.AssetTypeNative();
      final result = StellarAssetId.fromAsset(asset);
      expect(result, isA<NativeAssetId>());
      expect(result.id, "native");
      expect(result.scheme, stellarScheme);
    });

    test('fromAsset on an AlphaNum4 credit asset yields a matching IssuedAssetId',
        () {
      final asset = flutter_sdk.AssetTypeCreditAlphaNum4("USD", issuer);
      final result = StellarAssetId.fromAsset(asset);
      expect(result, isA<IssuedAssetId>());
      final issued = result as IssuedAssetId;
      expect(issued.code, "USD");
      expect(issued.issuer, issuer);
      expect(issued.sep38, "stellar:USD:$issuer");
    });

    test(
        'fromAsset on an AlphaNum12 credit asset yields a matching IssuedAssetId',
        () {
      final asset =
          flutter_sdk.AssetTypeCreditAlphaNum12("LONGASSET12", issuer);
      final result = StellarAssetId.fromAsset(asset);
      expect(result, isA<IssuedAssetId>());
      final issued = result as IssuedAssetId;
      expect(issued.code, "LONGASSET12");
      expect(issued.issuer, issuer);
    });

    test('fromAsset throws UnsupportedError on an unknown asset type', () {
      expect(
        () => StellarAssetId.fromAsset(_UnknownAsset()),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('fromAsset throws UnsupportedError on a liquidity pool share', () {
      final poolShare = flutter_sdk.AssetTypePoolShare(
        assetA: flutter_sdk.AssetTypeNative(),
        assetB: flutter_sdk.AssetTypeCreditAlphaNum4("USDC", issuer),
      );
      expect(
        () => StellarAssetId.fromAsset(poolShare),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('StellarAssetId Round-Trip Tests', () {
    test('NativeAssetId toAsset returns the native asset', () {
      final native = NativeAssetId();
      final asset = native.toAsset();
      expect(asset, isA<flutter_sdk.AssetTypeNative>());
      expect(asset.type, flutter_sdk.Asset.TYPE_NATIVE);
    });

    test('NativeAssetId survives a toAsset/fromAsset round-trip', () {
      final native = NativeAssetId();
      final restored = StellarAssetId.fromAsset(native.toAsset());
      expect(restored, native);
      expect(restored, isA<NativeAssetId>());
    });

    test('IssuedAssetId (AlphaNum4) toAsset preserves code and issuer', () {
      final issued = IssuedAssetId(code: "USD", issuer: issuer);
      final asset = issued.toAsset();
      expect(asset, isA<flutter_sdk.AssetTypeCreditAlphaNum4>());
      final credit = asset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(credit.code, "USD");
      expect(credit.issuerId, issuer);
    });

    test('IssuedAssetId (AlphaNum12) toAsset preserves code and issuer', () {
      final issued = IssuedAssetId(code: "LONGASSET12", issuer: issuer);
      final asset = issued.toAsset();
      expect(asset, isA<flutter_sdk.AssetTypeCreditAlphaNum12>());
      final credit = asset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(credit.code, "LONGASSET12");
      expect(credit.issuerId, issuer);
    });

    test('IssuedAssetId survives a toAsset/fromAsset round-trip', () {
      final issued = IssuedAssetId(code: "USD", issuer: issuer);
      final restored = StellarAssetId.fromAsset(issued.toAsset());
      expect(restored, isA<IssuedAssetId>());
      expect(restored, issued);
      final restoredIssued = restored as IssuedAssetId;
      expect(restoredIssued.code, "USD");
      expect(restoredIssued.issuer, issuer);
    });
  });

  group('IssuedAssetId Tests', () {
    test('sep38 and toString render the SEP-38 form', () {
      final issued = IssuedAssetId(code: "USDC", issuer: issuer);
      expect(issued.sep38, "stellar:USDC:$issuer");
      expect(issued.toString(), "stellar:USDC:$issuer");
      expect(issued.id, "USDC:$issuer");
    });

    test('equal code and issuer compare equal and share a hashCode', () {
      final a = IssuedAssetId(code: "USD", issuer: issuer);
      final b = IssuedAssetId(code: "USD", issuer: issuer);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing code compares unequal', () {
      final a = IssuedAssetId(code: "USD", issuer: issuer);
      final b = IssuedAssetId(code: "EUR", issuer: issuer);
      expect(a == b, isFalse);
    });

    test('differing issuer compares unequal', () {
      final a = IssuedAssetId(code: "USD", issuer: issuer);
      final b = IssuedAssetId(code: "USD", issuer: otherIssuer);
      expect(a == b, isFalse);
    });

    test('codes are case sensitive', () {
      final upper = IssuedAssetId(code: "USD", issuer: issuer);
      final lower = IssuedAssetId(code: "usd", issuer: issuer);
      expect(upper == lower, isFalse);
    });
  });

  group('NativeAssetId Tests', () {
    test('sep38 is the native SEP-38 form', () {
      expect(NativeAssetId().sep38, "stellar:native");
    });

    test('two NativeAssetId instances are equal and share a hashCode', () {
      final a = NativeAssetId();
      final b = NativeAssetId();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('FiatAssetId Tests', () {
    test('sep38 and toString render the ISO-4217 form', () {
      final fiat = FiatAssetId("USD");
      expect(fiat.sep38, "iso4217:USD");
      expect(fiat.toString(), "iso4217:USD");
    });

    test('equal currency codes compare equal and share a hashCode', () {
      final a = FiatAssetId("USD");
      final b = FiatAssetId("USD");
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing currency codes compare unequal', () {
      expect(FiatAssetId("USD") == FiatAssetId("EUR"), isFalse);
    });
  });

  group('AssetId Cross-Type Inequality Tests', () {
    test('NativeAssetId is not equal to an IssuedAssetId', () {
      final native = NativeAssetId();
      final issued = IssuedAssetId(code: "USD", issuer: issuer);
      expect(native == issued, isFalse);
      expect(issued == native, isFalse);
    });

    test('a stellar native asset is not equal to a fiat asset', () {
      // Typed as the common AssetId base so the comparison is statically
      // legal; the runtime operator== logic is still exercised.
      final AssetId native = NativeAssetId();
      final AssetId fiat = FiatAssetId("USD");
      expect(native == fiat, isFalse);
      expect(fiat == native, isFalse);
    });

    test('an issued stellar asset is not equal to a fiat asset', () {
      final AssetId issued = IssuedAssetId(code: "USD", issuer: issuer);
      final AssetId fiat = FiatAssetId("USD");
      expect(issued == fiat, isFalse);
      expect(fiat == issued, isFalse);
    });
  });

  group('AssetId Edge Case Tests', () {
    test('IssuedAssetId with empty code and issuer renders the empty SEP-38 form',
        () {
      final issued = IssuedAssetId(code: "", issuer: "");
      expect(issued.code, "");
      expect(issued.issuer, "");
      expect(issued.id, ":");
      expect(issued.sep38, "stellar::");
    });

    test('two empty IssuedAssetId instances are equal and share a hashCode', () {
      final a = IssuedAssetId(code: "", issuer: "");
      final b = IssuedAssetId(code: "", issuer: "");
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('FiatAssetId with an empty code renders the empty ISO-4217 form', () {
      final fiat = FiatAssetId("");
      expect(fiat.id, "");
      expect(fiat.sep38, "iso4217:");
    });
  });
}

/// A base-SDK [flutter_sdk.Asset] subtype that is neither native, credit
/// alphanum, nor pool share. Used to exercise the unknown-asset branch of
/// [StellarAssetId.fromAsset].
class _UnknownAsset extends flutter_sdk.Asset {
  @override
  String get type => "unknown";

  @override
  int get hashCode => 0;

  @override
  bool operator ==(Object object) => identical(this, object);

  @override
  flutter_sdk.XdrAsset toXdr() => throw UnimplementedError();

  @override
  flutter_sdk.XdrChangeTrustAsset toXdrChangeTrustAsset() =>
      throw UnimplementedError();

  @override
  flutter_sdk.XdrTrustlineAsset toXdrTrustLineAsset() =>
      throw UnimplementedError();
}
