// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';

class Sep38 {
  AuthToken? token;
  String serviceAddress;
  http.Client? httpClient;
  late flutter_sdk.SEP38QuoteService quoteService;

  Sep38(this.serviceAddress, {this.httpClient, this.token}) {
    quoteService =
        flutter_sdk.SEP38QuoteService(serviceAddress, httpClient: httpClient);
  }

  Future<QuotesInfoResponse> info() async {
    try {
      flutter_sdk.SEP38InfoResponse infoResponse =
          await quoteService.info(jwtToken: token?.jwt);
      return QuotesInfoResponse.from(infoResponse);
    } on Exception catch (e) {
      if (e is flutter_sdk.SEP38BadRequest) {
        throw BadRequestDataException(e.error, cause: e);
      }
      rethrow;
    }
  }

  Future<QuoteAssetIndicativePrices> prices(
      {required String sellAsset,
      required String sellAmount,
      String? sellDeliveryMethod,
      String? buyDeliveryMethod,
      String? countryCode}) async {
    try {
      flutter_sdk.SEP38PricesResponse pricesResponse =
          await quoteService.prices(
              sellAsset: sellAsset,
              sellAmount: sellAmount,
              sellDeliveryMethod: sellDeliveryMethod,
              buyDeliveryMethod: buyDeliveryMethod,
              countryCode: countryCode,
              jwtToken: token?.jwt);

      return QuoteAssetIndicativePrices.from(pricesResponse);
    } on Exception catch (e) {
      if (e is flutter_sdk.SEP38BadRequest) {
        throw BadRequestDataException(e.error, cause: e);
      }
      rethrow;
    }
  }

  Future<QuoteAssetPairIndicativePrice> price(
      {required String context,
      required String sellAsset,
      required String buyAsset,
      String? sellAmount,
      String? buyAmount,
      String? sellDeliveryMethod,
      String? buyDeliveryMethod,
      String? countryCode}) async {
    if ((sellAmount != null && buyAmount != null) ||
        (sellAmount == null && buyAmount == null)) {
      throw ValidationException(
          'The caller must provide either [sellAmount] or [buyAmount], but not both.');
    }

    try {
      flutter_sdk.SEP38PriceResponse priceResponse = await quoteService.price(
          context: context,
          sellAsset: sellAsset,
          buyAsset: buyAsset,
          sellAmount: sellAmount,
          buyAmount: buyAmount,
          sellDeliveryMethod: sellDeliveryMethod,
          countryCode: countryCode,
          jwtToken: token?.jwt);

      return QuoteAssetPairIndicativePrice.from(priceResponse);
    } on ArgumentError catch (a) {
      throw ValidationException(a.toString());
    } on Exception catch (e) {
      if (e is flutter_sdk.SEP38BadRequest) {
        throw BadRequestDataException(e.error, cause: e);
      }
      rethrow;
    }
  }

  Future<FirmQuote> requestQuote(
      {required String context,
      required String sellAsset,
      required String buyAsset,
      String? sellAmount,
      String? buyAmount,
      DateTime? expireAfter,
      String? sellDeliveryMethod,
      String? buyDeliveryMethod,
      String? countryCode,
      AuthToken? authToken}) async {
    AuthToken? sep10Token = authToken;
    sep10Token ??= token;
    if (sep10Token == null) {
      throw QuoteEndpointAuthRequired(
          'The requestQuote endpoint requires SEP-10 authentication');
    }
    flutter_sdk.SEP38PostQuoteRequest request =
        flutter_sdk.SEP38PostQuoteRequest(
            context: context,
            sellAsset: sellAsset,
            buyAsset: buyAsset,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            expireAfter: expireAfter,
            sellDeliveryMethod: sellDeliveryMethod,
            buyDeliveryMethod: buyDeliveryMethod,
            countryCode: countryCode);

    if ((sellAmount != null && buyAmount != null) ||
        (sellAmount == null && buyAmount == null)) {
      throw ValidationException(
          'The caller must provide either [sellAmount] or [buyAmount], but not both.');
    }
    try {
      flutter_sdk.SEP38QuoteResponse quoteResponse =
          await quoteService.postQuote(request, sep10Token.jwt);

      return FirmQuote.from(quoteResponse);
    } on ArgumentError catch (a) {
      throw ValidationException(a.toString());
    } on Exception catch (e) {
      if (e is flutter_sdk.SEP38BadRequest) {
        throw BadRequestDataException(e.error, cause: e);
      } else if (e is flutter_sdk.SEP38PermissionDenied) {
        throw QuoteRequestPermissionDenied(e.error, cause: e);
      }
      rethrow;
    }
  }

  Future<FirmQuote> getQuote(String quoteId, {AuthToken? authToken}) async {
    try {
      AuthToken? sep10Token = authToken;
      sep10Token ??= token;
      if (sep10Token == null) {
        throw QuoteEndpointAuthRequired(
            'The getQuote endpoint requires SEP-10 authentication');
      }

      flutter_sdk.SEP38QuoteResponse quoteResponse =
          await quoteService.getQuote(quoteId, sep10Token.jwt);
      return FirmQuote.from(quoteResponse);
    } on Exception catch (e) {
      if (e is flutter_sdk.SEP38BadRequest) {
        throw BadRequestDataException(e.error, cause: e);
      }
      rethrow;
    }
  }
}

class QuotesInfoResponse {
  List<QuoteInfoAsset> assets;
  QuotesInfoResponse(this.assets);

  static QuotesInfoResponse from(flutter_sdk.SEP38InfoResponse infoResponse) {
    List<QuoteInfoAsset> assets = List<QuoteInfoAsset>.empty(growable: true);

    for (var asset in infoResponse.assets) {
      assets.add(QuoteInfoAsset.from(asset));
    }

    return QuotesInfoResponse(assets);
  }
}

class QuoteInfoAsset {
  String asset;
  List<QuoteSellDeliveryMethod>? sellDeliveryMethods;
  List<QuoteBuyDeliveryMethod>? buyDeliveryMethods;
  List<String>? countryCodes;

  QuoteInfoAsset(this.asset,
      {this.sellDeliveryMethods, this.buyDeliveryMethods, this.countryCodes});

  static QuoteInfoAsset from(flutter_sdk.SEP38Asset value) {
    List<QuoteSellDeliveryMethod>? quoteSellDeliveryMethods;
    if (value.sellDeliveryMethods != null &&
        value.sellDeliveryMethods!.isNotEmpty) {
      quoteSellDeliveryMethods =
          List<QuoteSellDeliveryMethod>.empty(growable: true);
      for (var method in value.sellDeliveryMethods!) {
        quoteSellDeliveryMethods.add(QuoteSellDeliveryMethod.from(method));
      }
    }

    List<QuoteBuyDeliveryMethod>? quoteBuyDeliveryMethods;
    if (value.buyDeliveryMethods != null &&
        value.buyDeliveryMethods!.isNotEmpty) {
      quoteBuyDeliveryMethods =
          List<QuoteBuyDeliveryMethod>.empty(growable: true);
      for (var method in value.buyDeliveryMethods!) {
        quoteBuyDeliveryMethods.add(QuoteBuyDeliveryMethod.from(method));
      }
    }

    return QuoteInfoAsset(value.asset,
        sellDeliveryMethods: quoteSellDeliveryMethods,
        buyDeliveryMethods: quoteBuyDeliveryMethods,
        countryCodes: value.countryCodes);
  }
}

class QuoteSellDeliveryMethod {
  String name;
  String description;

  QuoteSellDeliveryMethod(this.name, this.description);

  static QuoteSellDeliveryMethod from(
      flutter_sdk.Sep38SellDeliveryMethod value) {
    return QuoteSellDeliveryMethod(value.name, value.description);
  }
}

class QuoteBuyDeliveryMethod {
  String name;
  String description;

  QuoteBuyDeliveryMethod(this.name, this.description);

  static QuoteBuyDeliveryMethod from(flutter_sdk.Sep38BuyDeliveryMethod value) {
    return QuoteBuyDeliveryMethod(value.name, value.description);
  }
}

class QuoteAssetIndicativePrices {
  List<QuoteBuyAsset> buyAssets;

  QuoteAssetIndicativePrices(this.buyAssets);

  static QuoteAssetIndicativePrices from(
      flutter_sdk.SEP38PricesResponse value) {
    List<QuoteBuyAsset> buyAssets = List<QuoteBuyAsset>.empty(growable: true);

    for (var asset in value.buyAssets) {
      buyAssets.add(QuoteBuyAsset.from(asset));
    }
    return QuoteAssetIndicativePrices(buyAssets);
  }
}

class QuoteBuyAsset {
  String asset;
  String price;
  int decimals;

  QuoteBuyAsset(this.asset, this.price, this.decimals);

  static QuoteBuyAsset from(flutter_sdk.SEP38BuyAsset value) {
    return QuoteBuyAsset(value.asset, value.price, value.decimals);
  }
}

class QuoteAssetPairIndicativePrice {
  String totalPrice;
  String price;
  String sellAmount;
  String buyAmount;
  ConversionFee fee;

  QuoteAssetPairIndicativePrice(
      this.totalPrice, this.price, this.sellAmount, this.buyAmount, this.fee);

  static QuoteAssetPairIndicativePrice from(
      flutter_sdk.SEP38PriceResponse value) {
    ConversionFee fee = ConversionFee.from(value.fee);
    return QuoteAssetPairIndicativePrice(
        value.totalPrice, value.price, value.sellAmount, value.buyAmount, fee);
  }
}

class ConversionFee {
  String total;
  String asset;
  List<ConversionFeeDetails>? details;

  ConversionFee(this.total, this.asset, {this.details});

  static ConversionFee from(flutter_sdk.SEP38Fee value) {
    List<ConversionFeeDetails>? details;
    if (value.details != null && value.details!.isNotEmpty) {
      details = List<ConversionFeeDetails>.empty(growable: true);
      for (var detail in value.details!) {
        details.add(ConversionFeeDetails.from(detail));
      }
    }

    return ConversionFee(value.total, value.asset, details: details);
  }
}

class ConversionFeeDetails {
  String name;
  String amount;
  String? description;

  ConversionFeeDetails(this.name, this.amount, {this.description});

  static ConversionFeeDetails from(flutter_sdk.SEP38FeeDetails value) {
    return ConversionFeeDetails(value.name, value.amount,
        description: value.description);
  }
}

class FirmQuote {
  String id;
  DateTime expiresAt;
  String totalPrice;
  String price;
  String sellAsset;
  String sellAmount;
  String buyAsset;
  String buyAmount;
  ConversionFee fee;

  FirmQuote(this.id, this.expiresAt, this.totalPrice, this.price,
      this.sellAsset, this.sellAmount, this.buyAsset, this.buyAmount, this.fee);

  static FirmQuote from(flutter_sdk.SEP38QuoteResponse value) {
    ConversionFee fee = ConversionFee.from(value.fee);
    return FirmQuote(
        value.id,
        value.expiresAt,
        value.totalPrice,
        value.price,
        value.sellAsset,
        value.sellAmount,
        value.buyAsset,
        value.buyAmount,
        fee);
  }
}
